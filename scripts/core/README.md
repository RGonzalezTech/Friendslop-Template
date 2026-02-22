# Core Systems

This folder holds the scene management lifecycle for the template. These scripts handle the loading overlay and report whether the client is loading or not.

## SceneManager ([`scene_manager.gd`](./scene_manager.gd))

This autoload is responsible for transitioning between scenes via background loading while showing a loading screen and updating the loading screen's progress.

- The [`LobbyManager`](../multiplayer/lobby/README.md) will request a scene change when the `active_scene_path` property is updated.
- It creates a LoadingOverlay so users know something is happening.
- It unloads the old world and loads the new one.
- It waits for the new scene to be fully ready before removing the loading screen.

**Flow Diagram**

```mermaid
sequenceDiagram
    participant NetworkLevelRoot
    participant LobbyManager
    participant SM as SceneManager
    participant Overlay as LoadingOverlay
    participant Loader as ResourceLoader

    LobbyManager->>SM: start_transition_to(path)
    activate SM
    SM->>Overlay: await fade_in()
    activate Overlay
    deactivate Overlay
    SM->>Loader: load_threaded_request(path)
    activate Loader
    SM-->>LobbyManager: is_loading_update(true)
    Note left of LobbyManager: This updates the player status<br/>to SCENE_LOADING
    
    loop Every Few Frames
        SM->>Loader: load_threaded_get_status()
    end
    
    Loader-->>SM: Resource Loaded
    deactivate Loader
    SM->>NetworkLevelRoot: change_scene_to_packed()
    NetworkLevelRoot->>SM: _ready() calls SceneManager.mark_scene_as_loaded(self)
    SM->>Overlay: await fade_out()
    activate Overlay
    deactivate Overlay
    SM-->>LobbyManager: is_loading_update(false)
    LobbyManager->>NetworkLevelRoot: signal player_status_update(id, SYNCED)
    note right of NetworkLevelRoot: NetworkLevelRoot only emits the signal if it is the server.
    NetworkLevelRoot->>NetworkLevelRoot: signal player_ready_for_gameplay(id)
    Note right of NetworkLevelRoot: The scene should pick up the signal<br/>and spawn the player or whatever
    deactivate SM
```

**How to use:** Call `SceneManager.start_transition_to("res://path/to/scene.tscn")` instead of the standard Godot change scene function.

## NetworkLevelRoot ([`network_level_root.gd`](./network_level_root.gd))

This node is responsible for informing the scene manager that the scene is loaded, and announcing players ready for gameplay.

To be used with the [PlayerSpawnManager](../multiplayer/player_spawning/README.md) to handle the lifecycle of clients.