extends GutTest

class MockSceneManager extends SceneManagerCode:
	var called: int = 0

	func _perform_scene_change(scene: PackedScene) -> void:
		called += 1

var _scene_manager: SceneManagerCode

func before_each():
	# Use partial_double so we can stub the scene change method
	_scene_manager = MockSceneManager.new()
	
	# Create a double for LoadingOverlay to verify fade_in/fade_out calls
	var overlay_double = double(LoadingOverlay).new()
	_scene_manager._loading_overlay = overlay_double
	
	add_child(_scene_manager)

func after_each():
	_scene_manager._loading_overlay.free()
	_scene_manager.free()

func test_ignores_same_path():
	var path = SceneManagerCode.LOBBY_MENU
	
	_scene_manager.start_transition_to(path)
	
	assert_true(_scene_manager.is_loading, "Should be loading")
	var initial_id = _scene_manager._active_scene_load_id
	
	# Try to transition again while loading SAME path
	_scene_manager.start_transition_to(path)
	
	assert_eq(_scene_manager._active_scene_load_id, initial_id, "Load ID should NOT increment for same path")
	# Verify fade_in was only called once
	assert_called(_scene_manager._loading_overlay.fade_in)
	assert_called_count(_scene_manager._loading_overlay.fade_in, 1)

func test_can_overwrite_transition():
	var path1 = SceneManagerCode.LOBBY_MENU
	var path2 = SceneManagerCode.MAIN_MENU
	
	_scene_manager.start_transition_to(path1)
	var initial_id = _scene_manager._active_scene_load_id
	
	# Transition to DIFFERENT path while loading should increment ID
	_scene_manager.start_transition_to(path2)
	
	assert_gt(_scene_manager._active_scene_load_id, initial_id, "Load ID SHOULD increment for different path")
	assert_eq(_scene_manager._target_scene, path2, "Target scene should be updated")

func test_fails_on_invalid_path():
	watch_signals(_scene_manager)
	var invalid_path = "res://non_existent_scene.tscn"
	
	await _scene_manager.start_transition_to(invalid_path)
	
	assert_signal_emitted(_scene_manager.load_failed)

func test_ignores_empty_paths():
	_scene_manager.start_transition_to("")
	assert_false(_scene_manager.is_loading, "Should not be loading for empty path")

func test_emits_is_loading_update():
	watch_signals(_scene_manager)
	_scene_manager.is_loading = true
	assert_signal_emitted_with_parameters(_scene_manager.is_loading_update, [true])
	_scene_manager.is_loading = false
	assert_signal_emitted_with_parameters(_scene_manager.is_loading_update, [false])

func test_mark_loaded_cleans_up_fade_out():
	_scene_manager.is_loading = true
	var dummy_node = Node.new()
	
	_scene_manager.mark_scene_as_loaded(dummy_node)
	
	assert_false(_scene_manager.is_loading, "is_loading should be false after mark_scene_as_loaded")
	assert_called(_scene_manager._loading_overlay.fade_out)
	dummy_node.free()

func test_completes_transition():
	# We use a real path because mocking ResourceLoader is hard.
	# The start_transition_to will trigger the timer.
	var path = "res://scenes/menu/MainMenu.tscn"
	_scene_manager.start_transition_to(path)
	
	# Wait for the loader to finish (THREAD_LOAD_LOADED)
	# This internal logic calls _perform_scene_change
	await wait_until(func(): return _scene_manager._active_scene_load_id > 0 and _scene_manager.is_stopped(), 2.0)
	
	assert_eq(_scene_manager.called, 1)
	
	# In a real game, the new scene would call mark_scene_as_loaded.
	# Since we stubbed it, we call it manually to finish the "loading" state.
	var mock_node = Node.new()
	_scene_manager.mark_scene_as_loaded(mock_node)
	
	assert_false(_scene_manager.is_loading, "is_loading should be false after transition completion")
	mock_node.free()

func test_go_to_main_menu_transitions():
	_scene_manager.go_to_main_menu()
	assert_eq(_scene_manager._target_scene, SceneManagerCode.MAIN_MENU)
	assert_true(_scene_manager.is_loading)
