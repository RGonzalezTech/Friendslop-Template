# Multiplayer Systems 📡

This is the heavy lifter of the template. It handles everything involved in getting players connected and playing together.

## 📂 Subsystems

- **`lobby/`**: Handles connected players and their meta data (Status, Name, peer_id, etc.)
- **`network/`**: The low-level `PeerManager` & Network Provider implementations.
- **`player_spawning/`**: Logic for how to spawn players in the world.
- **`replication/`**: Nodes for synchronizing world state, especially for late-joining players.

## 🏗️ Connection Architecture

```mermaid
graph TD
    User[User / Main Menu] -->|Click Host| PeerManager
    User -->|Click Join| PeerManager
    
    PeerManager -->|Select Provider| Provider{Provider Type}
    
    Provider -->|Use ENet| ENet[ENetNetworkProvider]
    Provider -->|Use Steam| Steam[SteamNetworkProvider]
    
    ENet -->|Create| MP[MultiplayerPeer]
    Steam -->|Create| MP
    
    MP -->|Assign to| Tree["GetTree().get_multiplayer()"]
```

## 🤝 Peer Manager

The **`PeerManager`** is your single source of truth for the connection state. Whether you are the Host or a Client, this script manages the `MultiplayerPeer`.

- **ENet**: Standard Godot networking. Good for testing and direct IP connections.
- **Steam**: Not yet integrated, but could be added as a network provider with minimal changes to the rest of the application.

## 🛠️ Core Components

- **`LobbyManager`**: Orchestrates the game session, tracking player readiness and broadcasting the active scene.
- **Handshake System**: Uses `HandshakeSpawner` and `HandshakeSynchronizer` to ensure late-joining clients are perfectly synced before they start playing.