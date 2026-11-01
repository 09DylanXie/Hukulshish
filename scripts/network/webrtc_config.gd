extends RefCounted
## Protocol limits shared by the browser client and the signaling service.

const MAX_PLAYERS: int = 3
const HOST_ID: int = 1
const DEFAULT_PORT: int = 9080
const PROTOCOL_VERSION: int = 1
const CONNECTION_TIMEOUT_SEC: float = 30.0
const INPUT_INTERVAL_SEC: float = 0.05
const INPUT_TIMEOUT_SEC: float = 0.5
const MAX_SIGNAL_BYTES: int = 65536
const MAX_CONNECTIONS: int = 96
const MAX_MESSAGES_PER_SECOND: int = 100
const ROOM_CODE_LENGTH: int = 8

# Supply deployment-specific STUN / TURN configuration at runtime.
# Never ship long-lived TURN credentials in the game repository.
const DEFAULT_ICE_SERVERS: Array[Dictionary] = []
