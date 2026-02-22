# Replication (The Handshake) 🤝

Multiplayer games often suffer from "race conditions"—like the server announcing "spawn" before the client has the scene loaded.

Godot's default `MultiplayerSpawner` is great, but it wasn't working with our use `get_tree().change_scene_to*()` so we created our own **Handshake Replication System** to guarantee reliability.

## 🕹️ How it Works

1.  **Connect**: Client connects to the Host.
2.  **Load**: Both parties load the map scene.
3.  **Ready Up**: Individual `HandshakeSynchronizer` nodes and `HandshakeSpawner` nodes tell the server: "Please let me in!"
4.  **Sync/Spawn**: Only after receiving this request does the Server replay events from the `HandshakeSpawner` and enable syncing from `HandshakeSynchronizer` nodes. 

## 📑 Handshake Sequence

```mermaid
sequenceDiagram
    participant Timer as HandshakeRetryTimer
    participant Sync as HandshakeSynchronizer
    participant Spawner as HandshakeSpawner
    participant Server

    Note over Sync, Server: 1. Setup Phase
    
    par Map Loading
        Sync->>Sync: Load Level
        Server->>Server: Load Level
    end

    Note over Sync, Server: 2. HandshakeSynchronizers (Visibility)
    
    loop Until Acknowledged (0.25s intervals)
        Timer->>Sync: signal sync_requested()
        Sync->>Server: _rpc_client_request_sync()
        
        Note over Server: Server grants visibility
        Server-->>Sync: set_visibility_for(client, true)
        Server->>Sync: _rpc_server_ack_sync()
        
        Sync->>Timer: ack()
    end

    Note over Sync, Server: 3. HandshakeSpawners (Spawning)
    
    loop Until Replay Acked (0.25s intervals)
        Timer->>Spawner: signal sync_requested()
        Spawner->>Server: _rpc_request_spawn_replay()
        
        Note over Server: Replay existing world state
        Server-->>Spawner: _rpc_spawn(packet) [N times]
        Server->>Spawner: _rpc_ack_spawn_replay()
        
        Spawner->>Timer: ack()
    end
```

## 🛠️ Key Components

-   **`HandshakeSpawner`**: Replaces the standard `MultiplayerSpawner`. It is built entirely through GDScript and RPCs, and it manages the instantiation of any node that is registered in the `spawnables` dictionary.
    - You map a label to a resource path in the `spawnables` dictionary.
    - When you call `spawn(type, params)`, it will use the `type` => `SpawnableResource` to `resource.spawn(params)` spawn the node.
    - When you call `despawn_id(s_id)`, it will use the `type` => `SpawnableResource` to `resource.teardown(node)` despawn the node.
-   **`HandshakeSynchronizer`**: An extension of the [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/tutorials/multiplayer/multiplayer_synchronizer.html) that only enables syncing when the client has requested it.
-   **`HandshakeRetryTimer`**: A helper that ensures requests are sent repeatedly until the server acknowledges them, overcoming potential packet loss or an un-ready scene tree.
-   **`SpawnRequest`**: A data object representing a pending spawn operation, including its type and specific parameters.

This system ensures that all clients can sync with retry behavior.