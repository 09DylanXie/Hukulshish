# Three-player WebRTC co-op

## Approved design

- Three players total: one host and two guests.
- Browser-compatible WebRTC gameplay transport.
- Each player owns their inventory, gold, and upgrade materials.
- Kill gold goes only to the player landing the killing blow. The first living
  collector owns each ground pickup.
- Players start with 7 HP in both modes. Normal enemy base HP is doubled in
  co-op; all boss base HP is multiplied by 5 total. Player, nest, companion and
  shield HP are unchanged. Difficulty and monster time scaling still apply.
- Nest bosses retain the current 240-HP base: 1200 in co-op. Mega Boss base HP
  becomes 10000. The Mega Boss shield remains 100.
- Each player can buy a permanent Revival unlock for 999 gold in the castle
  Gold Shop. It lasts for the run, permits repeated revivals, and cannot be
  purchased twice. It is not a consumable or a shared team unlock.
- Stand over a downed teammate for 3 uninterrupted seconds. Leaving resets
  progress; multiple helpers cannot combine their progress. Damage alone does
  not interrupt the interaction. After completion the teammate waits 5 more
  seconds, then returns to the castle with 5 HP and no shield.
- All three downed ends the run immediately, even if a castle return was already
  scheduled. Team defeat cancels those returns.
- Co-op shop and pause menus block local movement/casting without pausing the team.
- Normal mode is the first multiplayer target.

Shared gold mine upgrades and survival-run disconnect/rejoin rules still need
design decisions. Enemies retain their existing chase order but skip downed
players, allowing surviving teammates to continue the run.

## Current milestone: connection and movement test

The main menu's **Multiplayer (connection test)** button opens an isolated lobby.
The host creates an eight-character room code. Two guests can join; a fourth
connection is rejected. Players move colored markers with WASD or arrow keys.
The host simulates movement from bounded input vectors and broadcasts positions.
Guests cannot submit authoritative positions. Lost input expires instead of
leaving a character moving indefinitely.

This is not a multiplayer survival run yet. Enemies, projectiles, inventory,
revives, mobile movement controls, and late-join game snapshots are not connected.
The existing single-player run remains available through **Start**.

## Implemented game-side mechanics

`GameState` now uses the `RunState` class so each co-op player can have a separate
progress instance. `Game.add_coop_player()` creates the two guest actors and
their inventories. Once all three are registered, the host-owned
`CoopRevivalController` runs their interaction and respawn timers. The player
scene keeps a downed body at the death location, stops its movement/casting,
and exposes castle revival. The shop exposes the permanent unlock only in co-op.

Player spells, split/sniper shots, chain hits, fire zones and companions carry
their originating player's state. The host can therefore credit the final blow
to that inventory, including when delayed fire damage kills an enemy. Shared
pickups reject bodies and credit their first living collector.

These game-side hooks are tested locally; the connection-test lobby does not
yet launch and replicate this survival scene. A session driver must connect
guest inputs, actor/world snapshots, per-player HUDs, shop requests and end
screens before this becomes playable online co-op.

Balance values live in `resources/multiplayer/coop_rules.tres`.

## Local setup

Use the project's pinned Godot version from README.md. In PowerShell, replace
`C:\path\Godot.exe` with the installed executable:

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://scripts/network/signaling_server.gd
```

This starts the signaling service at `ws://127.0.0.1:9080`. It does not need a
WebRTC native extension because it only relays JSON over WebSockets.

For the clients, either use a browser export served over local HTTP, or install
the matching [Godot webrtc-native extension](https://github.com/godotengine/webrtc-native)
for native editor/desktop testing. WebRTC is built into Godot's browser export.
No native extension has been added to this repository.

1. Open three browser windows running the game and select the connection test.
2. Use the same signaling URL in all windows. Leave ICE servers as `[]` for an
   initial same-machine test. Browser/network restrictions may still require ICE servers.
3. Select **Host room** in the first window and copy the assigned code.
4. Enter the code in each other window and select **Join room**.
5. Click outside text fields and move with WASD. All windows should show the same
   three markers, with only the focused window controlling its own marker.
6. Try joining with a fourth window: expect a full-room error.
7. Leave as a guest: the host should remove that marker and permit a replacement.
8. Leave as the host: both guests should return to a disconnected state.

Keep the signaling service running for the lifetime of the room. This prototype
closes the room when the signaling connection or host is lost. It has no host
migration, reconnection protocol, or accounts.

## Internet deployment

The itch.io export is the browser client. Run the signaling script on a separate
server behind a TLS reverse proxy that supports WebSocket upgrades. Configure the
proxy with the allowed game origins, connection limits, and request limits.

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://scripts/network/signaling_server.gd -- --bind=127.0.0.1 --port=9080
```

Use the public `wss://` URL in the lobby. HTTPS pages cannot use an insecure
`ws://` endpoint. The signaling script defaults to loopback so it can safely sit
behind a proxy; use an explicit bind address for a deliberate LAN setup.

Provide ICE server configuration through the lobby's JSON field, for example:

```json
[
  {"urls": ["stun:YOUR_STUN_HOST:3478"]},
  {
    "urls": ["turn:YOUR_TURN_HOST:3478?transport=udp"],
    "username": "TEMPORARY_USERNAME",
    "credential": "TEMPORARY_CREDENTIAL"
  }
]
```

STUN helps discover reachable network addresses. TURN relays traffic when direct
connections fail. Use short-lived TURN credentials; do not commit deployment
secrets. The examples are placeholders, not working service addresses. A future
deployment should fetch temporary ICE settings rather than asking players for JSON.

The signaling service creates room membership and assigns peer IDs itself. It
only forwards SDP/ICE between members of the same room and only along host/guest
connections. Room codes are invitation secrets, not authenticated accounts.
Gameplay uses `WebRTCMultiplayerPeer.create_server()` on peer 1 and
`create_client()` on guests. Godot relays guest peer discovery through the host.

No public service or hosting account has been provisioned by this change.

## Automated checks

With the signaling service running, run its room protocol integration checks:

```powershell
node tests/network/signaling_server_test.mjs
```

The test uses Node's built-in WebSocket client. It checks the three-player cap,
server-assigned sender IDs, room isolation, guest replacement, host departure,
and incompatible protocol versions. It does not establish WebRTC data channels.

Run the lobby construction and cleanup check with the project autoloads:

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://tests/network/lobby_smoke_test.gd
```

Both checks passed during development using Godot 4.7.2 and Node 24.22.0.
The game-side mechanics integration suite also passes in Godot 4.7.2:

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://tests/network/coop_mechanics_test.gd
```

It checks unchanged player/nest HP, enemy/boss scaling, personal unlock purchases,
interruptions, separate 3-second and 5-second timers, repeat use, team wipes,
kill attribution, augmentation ownership, first-collector pickups, co-op shop
behavior, and guest actor registration in the actual Game scene.

The three-browser movement test and internet/TURN connectivity still need to be
run. This machine's `4.7.2.stable` export templates directory was empty, and the
project currently has desktop export presets only. Install matching Web templates
and add a Web export preset before running the browser test.

## Following milestones

1. Connect the independent player states to the WebRTC session's peer IDs.
2. Create the shared map on the host and send the maze layout, mine positions,
   and initial state to guests before starting simulation.
3. Connect the player input/casting ownership hooks to guest messages and bind
   each guest's HUD to its own authoritative state.
4. Run spawning, enemy targeting, damage, drop rolls, and pickup claims on the host.
5. Validate upgrade purchases against each player's authoritative inventory.
6. Replicate revive progress, body/respawn state, team defeat and victory; add
   the agreed disconnect handling.
7. Test three real browser devices, latency, TURN-only connectivity, mobile input,
   and dense combat before enabling a public multiplayer run.

## References

- [Godot WebRTC tutorial](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html)
- [WebRTCMultiplayerPeer API](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html)
- [WebRTCPeerConnection API](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html)
