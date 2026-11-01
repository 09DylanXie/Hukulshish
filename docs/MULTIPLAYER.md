# Three-player WebRTC co-op

> **Status:** co-op works over LAN, tested with three real game processes. The WebRTC path is written
> but hasn't been tested end to end, because that needs a browser build. Internet play also needs
> a signaling server and TURN, which nobody has deployed yet.

## Approved design

- Three players total: one host and two guests.
- Browser-compatible WebRTC gameplay transport.
- Each player owns their inventory, gold, and upgrade materials.
- Kill gold goes only to the player landing the killing blow. The first living
  collector owns each ground pickup.
- Players start with 7 HP in both modes. Normal enemy base HP is doubled in
  co-op; all boss base HP is multiplied by 5 total. Player, nest, companion and
  shield HP are unchanged. Difficulty still applies, and each descent multiplies
  HP by 2× on top of everything else.
- Nest bosses have 480 base HP: 2400 in co-op. They take 30% less incoming
  damage for the first 5 seconds after spawning, including fire damage. Mega Boss base HP
  becomes 10000. The Mega Boss shield remains 100.
- Each player can buy a permanent Revival unlock for 999 gold at the Gold
  stall. It lasts for the run, permits repeated revivals, and cannot be
  purchased twice. It is not a consumable or a shared team unlock.
- Stand over a downed teammate for 3 uninterrupted seconds. Leaving resets
  progress; multiple helpers cannot combine their progress. Damage alone does
  not interrupt the interaction. After completion the teammate waits 5 more
  seconds, then returns to the castle with 5 HP and no shield.
- All three downed ends the run immediately, even if a castle return was already
  scheduled. Team defeat cancels those returns.
- Co-op shop and pause menus block local movement/casting without pausing the team.
- Every player must enter a portal to descend. Anyone who enters early waits in a
  purgatory void layer until the rest arrive. The same applies to a two-player game.
- Catacombs darkness applies to each player separately.
- Normal mode is the first multiplayer target.

Mines, disconnects and enemy targeting are covered in `AGENTS.md` §9.

## How co-op works

The host runs the only real game. Guests send their input and shop requests to the host, and draw
the world snapshots it sends back 20 times a second. A guest's own movement is predicted locally,
so it responds immediately, and is corrected if the host disagrees.

`scripts/autoload/coop.gd` owns the connection and network messages,
`scripts/multiplayer/coop_host_sync.gd` packs snapshots, and
`scripts/multiplayer/coop_guest_view.gd` draws them. LAN and WebRTC only differ in how the
connection is created, so everything above that layer is shared.

## Trying it

**LAN (desktop):** works from the editor with nothing extra installed.

1. In Godot, open **Debug → Customize Run Instances**, enable it, and set 3 instances.
2. Press Play. In one window choose **Multiplayer → Host LAN game**.
3. In the others choose **Join LAN game**, leaving the address as `127.0.0.1`.
4. On the host, pick the settings and press **Start game**. Two players is enough.

To play on real computers, the guests enter the host's local IP address. The host may need to allow
UDP port 9081 through their firewall.

**WebRTC (browser):** this is what an itch.io build uses. It needs a Web export, and Godot's Web export
templates aren't installed yet. Native desktop builds can't use WebRTC without the webrtc-native
extension, so LAN is the way to test on desktop.

## WebRTC setup

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

1. Open three browser windows running the game and choose **Multiplayer**.
2. Use the same signaling URL in all windows. Leave ICE servers as `[]` for an
   initial same-machine test. Browser/network restrictions may still require ICE servers.
3. Select **Host room** in the first window and copy the assigned code.
4. Enter the code in each other window and select **Join room**.
5. On the host, press **Start game** and play.
6. Try joining with a fourth window: expect a full-room error.
7. Leave as a guest: the run should continue for everyone else.
8. Leave as the host: both guests should return to the Main Menu with a message.

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

Run a real three-player game across three processes, which covers connecting, movement, shop
purchases, drops, the portal and void, layer changes, a guest leaving, and a team wipe:

```bash
bash tests/network/run_coop_live.sh '/path/to/Godot_console.exe'
```

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

## What's left

1. Install the Web export templates, add a Web export preset, and run the WebRTC steps above.
2. Deploy the signaling service behind `wss://`, and provide STUN and TURN.
3. Test on real networks, including latency and TURN-only connections.
