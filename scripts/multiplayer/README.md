# Multiplayer Systems 📡

This is the heavy lifter of the template. It handles everything involved in getting players connected and playing together.

## 📂 Subsystems

- **[`lobby/`](./lobby/README.md)**: Handles connected players and their meta data (Status, Name, peer_id, etc.)
- **[`network/`](./network/README.md)**: The low-level `PeerManager` & Network Provider implementations.
- **[`player_spawning/`](./player_spawning/README.md)**: Logic for how to spawn players in the world.
- **[`replication/`](./replication/README.md)**: Nodes for synchronizing world state, especially for late-joining players.

## 🏗️ Connection Architecture

```mermaid
sequenceDiagram
    participant User
    participant MainMenu as Main Menu
    participant PM as PeerManager
    participant LM as LobbyManager
    participant SM as SceneManager
    participant PS as PlayerSpawnManager

    User->>MainMenu: Click Host/Join
    activate MainMenu
    MainMenu->>PM: set_provider(ENet/Steam)
    MainMenu->>PM: host/join()
    deactivate MainMenu
    activate PM
    Note right of PM: The provider is responsible for<br/>creating the MultiplayerPeer

    PM-->>LM: signal connection_established()
    deactivate PM

    activate LM
    LM->>LM: Lobby synchronizes with host<br/>gets active_scene_path
    LM->>SM: start_transition_to(active_scene_path)
    deactivate LM

    activate SM
    Note over SM: Background Scene Loading<br/>& Loading Screen
    Note over LM, PS: This is the simplified version
    SM-->>LM: done loading signal
    deactivate SM

    activate LM
    LM->>PS: player_ready_for_gameplay()
    deactivate LM

    activate PS
    PS->>PS: Instance Player Character
    deactivate PS
```

## 🤝 Peer Manager

The **`PeerManager`** is your single source of truth for the connection state. Whether you are the Host or a Client, this script manages the `MultiplayerPeer`.

- **ENet**: Standard Godot networking. Good for testing and direct IP connections.
- **Steam**: Not yet integrated, but could be added as a network provider with minimal changes to the rest of the application.

## 🛠️ Core Components

- **[`LobbyManager`](../lobby/README.md)**: Orchestrates the game session, tracking player readiness and broadcasting the active scene.
- **[`Handshake System`](../multiplayer/replication/README.md)**: Uses `HandshakeSpawner` and `HandshakeSynchronizer` to ensure late-joining clients are perfectly synced to your gameplay scenes before they start playing.