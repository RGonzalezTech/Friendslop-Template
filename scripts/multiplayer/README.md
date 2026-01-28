# Multiplayer Components

This directory manages networking, lobby state, and player synchronization.

## System Overview

```mermaid
classDiagram
    direction LR
    class PeerManager {
        <<Autoload>>
        +BaseNetworkProvider _provider
        +signal connection_established
        +signal connection_shutdown
        +set_provider(provider)
        +host_game()
        +join_game()
        +shutdown()
    }
    class BaseNetworkProvider {
        <<Abstract>>
        +host_game()*
        +join_game()*
        +shutdown()*
    }
    class ENetNetworkProvider {
        +String address
        +int port
    }
    class SteamNetworkProvider {
        +int lobby_id
    }
    class LobbyManager {
        <<Autoload>>
        +Lobby current_lobby
        +signal player_joined(peer_id)
        +signal player_left(peer_id)
        +initialize_lobby_as_host()
        +reset_lobby()
        +get_all_players()
    }
    class Lobby {
        +State state
        +int max_players
        +int host_id
        +String active_map_path
    }
    class LobbyPlayer {
        +int peer_id
        +String player_name
        +bool is_ready
        +Status status
    }

    PeerManager o-- BaseNetworkProvider : Uses
    BaseNetworkProvider <|-- ENetNetworkProvider
    BaseNetworkProvider <|-- SteamNetworkProvider
    PeerManager ..> LobbyManager : Triggers Init
    LobbyManager *-- Lobby : Manages
    LobbyManager *-- LobbyPlayer : Spawns (via Spawner)
```

## PeerManager

`PeerManager` (Autoload) abstracts the network interface, handling the creation and destruction of the `MultiplayerPeer`. It delegates actual connection logic to a `BaseNetworkProvider`.

The connection process is **asynchronous**. You should listen to the `connection_established` and `connection_shutdown` signals.

### Signals
- `connection_attempt_started`: Emitted when `host_game()` or `join_game()` is called.
- `connection_established`: Emitted when the peer is ready (server started or client connected).
- `connection_shutdown(reason)`: Emitted when the peer is closed or disconnects.

### Usage
```gdscript
# ENet
PeerManager.set_provider(ENetNetworkProvider.new("127.0.0.1", 7000))
PeerManager.host_game()

# Steam (Skeleton)
PeerManager.set_provider(SteamNetworkProvider.new(steam_lobby_id))
PeerManager.join_game()
```

### Host Game Flow

```mermaid
sequenceDiagram
    participant User
    participant PM as PeerManager
    participant Provider as NetworkProvider
    participant LM as LobbyManager
    participant SM as SceneManager

    User->>PM: host_game()
    PM->>PM: emit connection_attempt_started
    PM->>Provider: host_game()
    Provider->>Provider: create_server()
    Provider-->>PM: connection_created(peer)
    PM->>PM: multiplayer.peer = peer
    PM->>PM: emit connection_established
    PM-->>LM: connection_established signal
    LM->>LM: initialize_lobby_as_host()
    LM->>SM: start_transition_to(LOBBY_MENU)
```

### Join Game Flow

```mermaid
sequenceDiagram
    participant User
    participant PM as PeerManager
    participant Provider as NetworkProvider
    participant LM as LobbyManager
    
    User->>PM: join_game()
    PM->>PM: emit connection_attempt_started
    PM->>Provider: join_game()
    Provider->>Provider: create_client()
    Provider-->>PM: connection_created(peer)
    PM->>PM: multiplayer.peer = peer
    
    Note over PM, Provider: Async Wait for Connection...
    
    Provider-->>PM: connected_to_server (internal godot signal)
    PM->>PM: emit connection_established
    PM-->>LM: connection_established signal
```

---

## LobbyManager

`LobbyManager` (Autoload) governs the session logic above the transport layer. It manages the `Lobby` state and the player collection.

### Key Features
- **Player Spawning**: Uses a `MultiplayerSpawner` to replicate `LobbyPlayer` nodes across all clients automatically.
- **Node Management**: Maintains a `LobbyPlayers` container for organized player node management.
- **Unified Signals**: Emits `player_joined` and `player_left` based on internal node lifecycle events.

---

## Data Structures

### Lobby
A synchronized node representing the overall session state.
- **Synchronized Properties**: `active_map_path`, `state`, `max_players`, `host_id`.
- **States**: `NOT_CONNECTED`, `SERVER_LOADING`, `LOBBY`, `IN_GAME`, `POST_GAME`.

### LobbyPlayer
Represents a connected user. It uses TWO `MultiplayerSynchronizer` nodes for granular authority control:
- **PlayerSynchronizer**: Owned by the player. Syncs `player_name` and `is_ready`.
- **ServerSynchronizer**: Owned by the server. Syncs `status`.

---

## Network Providers

All providers inherit from `BaseNetworkProvider` and implement:
- `host_game()`: Initializes the server peer.
- `join_game()`: Initializes the client peer.
- `shutdown()`: Cleans up the peer and resources.

| Provider | Tech | Connectivity |
| :--- | :--- | :--- |
| `ENetNetworkProvider` | UDP/ENet | IP & Port |
| `SteamNetworkProvider` | Steam Networking | Steam Lobby ID |
