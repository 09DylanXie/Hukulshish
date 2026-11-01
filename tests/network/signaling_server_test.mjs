// Run the signaling service first, then: node tests/network/signaling_server_test.mjs
// Requires Node.js with a built-in WebSocket client; no npm dependencies.
import assert from 'node:assert/strict';

const url = process.argv[2] ?? 'ws://127.0.0.1:9080';
const clients = [];

async function connect() {
  const socket = new WebSocket(url);
  const messages = [];
  socket.addEventListener('message', event => messages.push(JSON.parse(event.data)));
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('WebSocket connection timed out')), 3000);
    socket.addEventListener('open', () => { clearTimeout(timer); resolve(); }, { once: true });
    socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Cannot reach signaling service')); }, { once: true });
  });
  const client = {
    socket,
    messages,
    send: message => socket.send(JSON.stringify(message)),
    async receive(type) {
      const deadline = Date.now() + 3000;
      while (Date.now() < deadline) {
        const index = messages.findIndex(message => message.type === type);
        if (index !== -1) return messages.splice(index, 1)[0];
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      throw new Error(`Timed out waiting for ${type}; received ${JSON.stringify(messages)}`);
    },
  };
  clients.push(client);
  return client;
}

async function hostRoom() {
  const host = await connect();
  host.send({ type: 'create', version: 1 });
  const joined = await host.receive('joined');
  assert.equal(joined.id, 1);
  assert.match(joined.room, /^[A-HJ-NP-Z2-9]{8}$/);
  return { host, code: joined.room };
}

try {
  const { host, code } = await hostRoom();
  const guest2 = await connect();
  guest2.send({ type: 'join', version: 1, room: code.toLowerCase() });
  assert.equal((await guest2.receive('joined')).id, 2);
  assert.equal((await host.receive('peer_joined')).id, 2);

  const guest3 = await connect();
  guest3.send({ type: 'join', version: 1, room: code });
  assert.equal((await guest3.receive('joined')).id, 3);
  assert.equal((await host.receive('peer_joined')).id, 3);

  const extra = await connect();
  extra.send({ type: 'join', version: 1, room: code });
  assert.match((await extra.receive('error')).message, /three players/);
  console.log('PASS: three members admitted; fourth member rejected');

  const offer = { type: 'description', kind: 'offer', sdp: 'test-offer' };
  host.send({ type: 'signal', to: 2, data: offer });
  assert.deepEqual(await guest2.receive('signal'), { type: 'signal', from: 1, data: offer });
  const answer = { type: 'description', kind: 'answer', sdp: 'test-answer' };
  guest2.send({ type: 'signal', from: 3, to: 1, data: answer });
  assert.deepEqual(await host.receive('signal'), { type: 'signal', from: 2, data: answer });
  console.log('PASS: signaling routes both ways; forged sender ID is ignored');

  const other = await hostRoom();
  assert.notEqual(other.code, code);
  guest2.send({ type: 'signal', to: 3, data: answer });
  extra.send({ type: 'signal', to: 1, data: answer });
  host.send({ type: 'signal', to: 99, data: offer });
  // A valid ordered marker confirms the preceding requests have been processed.
  guest2.send({ type: 'signal', to: 1, data: { ...answer, sdp: 'marker' } });
  assert.equal((await host.receive('signal')).data.sdp, 'marker');
  await new Promise(resolve => setTimeout(resolve, 100));
  assert.equal(guest3.messages.some(message => message.type === 'signal'), false);
  assert.equal(other.host.messages.some(message => message.type === 'signal'), false);
  console.log('PASS: guests cannot signal each other; non-members cannot relay');

  guest2.socket.close();
  assert.equal((await host.receive('peer_left')).id, 2);
  extra.send({ type: 'join', version: 1, room: code });
  assert.equal((await extra.receive('joined')).id, 2);
  assert.equal((await host.receive('peer_joined')).id, 2);
  console.log('PASS: guest disconnect frees a slot for a replacement');

  host.socket.close();
  await guest3.receive('room_closed');
  await extra.receive('room_closed');
  const missing = await connect();
  missing.send({ type: 'join', version: 1, room: code });
  assert.match((await missing.receive('error')).message, /not found/);
  console.log('PASS: host departure closes the room for both guests');

  const incompatible = await connect();
  incompatible.send({ type: 'create', version: 999 });
  assert.match((await incompatible.receive('error')).message, /versions/);
  console.log('PASS: incompatible protocol version rejected');
} finally {
  for (const client of clients) client.socket.close();
}
