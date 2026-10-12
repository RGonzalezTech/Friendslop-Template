extends GutTest

var _lobby: Lobby

func before_each():
	_lobby = Lobby.new()

func after_each():
	if _lobby:
		_lobby.free()

func test_max_players_defaults_to_4():
	assert_eq(_lobby.max_players, 4, "Default max_players should be 4")

func test_host_id_defaults_to_1():
	assert_eq(_lobby.host_id, 1, "Default host_id should be 1")

func test_state_defaults_to_not_connected():
	assert_eq(_lobby.state, Lobby.State.NOT_CONNECTED, "Default state should be NOT_CONNECTED")

func test_active_scene_path_defaults_to_empty():
	assert_eq(_lobby.active_scene_path, "", "Default active_scene_path should be empty string")

func test_synchronizer_is_created():
	assert_not_null(_lobby._synchronizer, "Synchronizer should exist after _init")

func test_synchronizer_registers_expected_properties():
	var config := _lobby._synchronizer.replication_config
	var properties: Array[NodePath] = config.get_properties()
	var paths: Array[String] = []
	for prop in properties:
		paths.append(str(prop))

	assert_true(paths.has(":active_scene_path"), "Should sync active_scene_path")
	assert_true(paths.has(":state"), "Should sync state")
	assert_true(paths.has(":max_players"), "Should sync max_players")
	assert_true(paths.has(":host_id"), "Should sync host_id")
	assert_eq(paths.size(), 4, "Should sync exactly 4 properties")