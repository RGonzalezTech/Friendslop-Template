# Lobby System 👥

This folder contains the nodes for tracking connected players and their name/status in a multiplayer session. The lobby is also responsible for announcing the current scene to all players.

## 📂 Components

-   [`LobbyManager`](./lobby_manager.gd): This autoload orchestrates the lobby & lobby player lifecycles, handling player joins/leaves, status updates, and it leverages [SceneManager](../../core/README.md) for scene transitions.
    - The [Lobby](./lobby.gd) node is a data container that represents the current lobby status and the active map.
    - [LobbyPlayer](./lobby_player.gd) nodes are data containers that represent a connected peer and their name/status (`CONNECTING`, `SCENE_LOADING`, `SYNCED`, `IN_GAME`).
    - Both are synchronized via [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html). MultiplayerSync/Spawn nodes work best in autoloads.

## 🏗️ Architecture Overview

```mermaid
sequenceDiagram
    participant PM as PeerManager
    participant LM as LobbyManager
    participant LN as Lobby
    participant MS as MultiplayerSpawner
    participant LP as LobbyPlayer
    participant SM as SceneManager

    PM->>LM: signal connection_established
    activate LM
    alt as server
        LM->>LN: configure lobby state for hosting
        activate LN
        Note right of LN: Lobby state is broadcast<br/> via MultiplayerSynchronizer
        deactivate LN
    end
    loop per connected peer
        LM->>MS: MultiplayerSpawner.spawn(peer_id)
        activate MS
        Note right of MS: MultiplayerSpawner handles spawning<br/> LobbyPlayer on all peers.
        MS->>LP: Instances LobbyPlayer
        activate LP
        LP-->>LM: signal player_joined
        deactivate LP
        deactivate MS
    end
    deactivate LM
    
    alt scene changes
        LN-->>LM: signal scene_changed
        activate LM
        Note right of LN: When the server updates active_scene_path,<br/>LobbyManager will request a scene change.
        LM->>SM: SceneManager.start_transition_to(active_scene_path)
        activate SM
        Note right of SM: SceneManager will fade in<br/>loading overlay and<br/>start background loading.
        SM-->>LM: signal is_loading_update(true)
        LM->>LP: update_player_status(Status.SCENE_LOADING)
        Note right of LM: All peers are now loading the scene.
        Note right of SM: Once the new scene reports ready,<br/>SceneManager will fade out<br/>loading overlay.
        SM-->>LM: signal is_loading_update(false)
        deactivate SM
        LM->>LP: update_player_status(Status.SYNCED)
        deactivate LM
    end 
```
