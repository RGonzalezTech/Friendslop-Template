class_name SceneManagerCode
extends Timer

## Manages high-level scene transitions.
## The scene manager shows a loading overlay while a scene is loading,
## and handles the background loading of scenes.
## 
## Example:
## [code]
## SceneManager.start_transition_to("res://scenes/Lobby.tscn")
## SceneManager.go_to_main_menu()
## [/code]

## The default `MainMenu` scene.
const MAIN_MENU: String = "res://scenes/menu/MainMenu.tscn"
## The default `Lobby` scene.
const LOBBY_MENU: String = "res://scenes/menu/Lobby.tscn"

## Emitted when the scene loader is active or not.
signal is_loading_update(is_loading: bool)
## Emitted when a scene load fails.
signal load_failed(reason: String)

## The scene path we are aiming to load.
var _target_scene: String = ""
## The ID of the current load request.
var _active_scene_load_id: int = 0

## Whether or not a scene is currently loading.
var is_loading: bool = false:
    set(value):
        if value == is_loading:
            return
        is_loading = value
        is_loading_update.emit(is_loading)

## The currently loaded scene path.
var _current_scene_path: String = ""
## The currently loaded scene node.
## Not used for anything yet, but is registered when the scene
## calls [mark_scene_as_loaded].
var _current_scene_node: Node

## The loading overlay, created in [_init].
var _loading_overlay: LoadingOverlay

#region init
func _init() -> void:
    _init_loading_overlay()
    _init_timer_config()

func _init_loading_overlay() -> void:
    var loading_canvas: CanvasLayer = CanvasLayer.new()
    loading_canvas.layer = 100 # Should be higher than any other canvas layer
    
    const LOADING_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/LoadingOverlay.tscn")
    _loading_overlay = LOADING_OVERLAY_SCENE.instantiate()
    loading_canvas.add_child(_loading_overlay)
    add_child(loading_canvas)

func _init_timer_config() -> void:
    wait_time = 0.2
    one_shot = false
    autostart = false
    timeout.connect(_on_load_status_check)
#endregion

#region API
## Transitions the scene to a new scene path.
## This function will fade in the loading overlay and start loading the new scene.
## If the new scene is the same as the current scene, this function will do nothing.
func start_transition_to(path: String) -> void:
    if path == "":
        # Ignore empty paths
        return
    
    if (_current_scene_path == path and not is_loading):
        # Ignore if the scene is already loaded
        return

    if (_target_scene == path and is_loading):
        # Ignore if we are already loading this scene
        return
    
    if not ResourceLoader.exists(path):
        load_failed.emit("Scene does not exist: " + path)
        return
    
    # This allows a scene load to be overwritten by another
    # while the fade-in / loading overlay is still active
    # This is useful for when a scene load is triggered while another is in progress
    _active_scene_load_id += 1
    var this_scene_load_id = _active_scene_load_id
    
    _target_scene = path
    is_loading = true
    await _loading_overlay.fade_in()
    
    if this_scene_load_id != _active_scene_load_id:
        # Another load overtook this one during the fade-in
        # So, let the other one continue
        return
    
    # Assume we are the latest load, so continue
    var err = ResourceLoader.load_threaded_request(_target_scene)
    if err != OK:
        load_failed.emit("Failed to load scene: " + _target_scene)
        mark_scene_as_loaded(get_tree().root)
        return
    
    start() # Start checking for load completion

## Transitions to the main menu.
func go_to_main_menu() -> void:
    # Main menu will disconnect and reset the lobby
    start_transition_to(MAIN_MENU)

## Marks the current scene as loaded.
## Called by the individual game scene when ready.
## This function will register the scene node and fade out the loading overlay.
func mark_scene_as_loaded(node: Node) -> void:
    _current_scene_node = node
    is_loading = false
    _loading_overlay.fade_out()
#endregion

#region signals
func _on_load_status_check() -> void:
    var this_tick_id = _active_scene_load_id

    var progress_holder = []
    var status = ResourceLoader.load_threaded_get_status(_target_scene, progress_holder)

    if this_tick_id != _active_scene_load_id:
        # Another transition overtook this one during the status check
        # The next tick will handle it
        return
    
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            var progress = progress_holder[0] if progress_holder.size() > 0 else 0
            _loading_overlay.update_progress(progress)
        ResourceLoader.THREAD_LOAD_LOADED:
            stop()
            var scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene)
            _perform_scene_change(scene)
        [ResourceLoader.THREAD_LOAD_FAILED,
        ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
            stop()
            load_failed.emit("Failed to load scene: " + _target_scene)
#endregion

## Performs the actual scene change.
## Overridden in tests to prevent the test runner from being replaced.
func _perform_scene_change(scene: PackedScene) -> void:
    get_tree().change_scene_to_packed(scene)
    _current_scene_path = scene.resource_path
