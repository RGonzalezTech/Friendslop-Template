extends GutTest

## Verifies the modular device-mapping modal compiles, instantiates, builds
## columns from LocalCoopManager state, and reacts to moves.

const MODAL_SCENE := preload("res://scenes/ui/device_mapping/DeviceMappingModal.tscn")

func _build_manager(gamepad_ids: Array[int] = []) -> LocalCoopManagerCode:
	var mock = double(InputProvider).new()
	stub(mock, "get_connected_joypads").to_return(gamepad_ids)
	var mgr = LocalCoopManagerCode.new()
	mgr.input_provider = mock
	add_child_autofree(mgr)
	return mgr

func _build_modal(player_count: int, gamepad_ids: Array[int] = []) -> DeviceMappingModal:
	var modal = MODAL_SCENE.instantiate()
	add_child_autofree(modal)
	modal.coop_manager = _build_manager(gamepad_ids)
	modal.open_mapping(player_count)
	return modal

func test_modal_scene_loads() -> void:
	var scene: PackedScene = load("res://scenes/ui/device_mapping/DeviceMappingModal.tscn")
	assert_not_null(scene, "DeviceMappingModal.tscn should load")
	var modal = scene.instantiate()
	add_child_autofree(modal)
	assert_is(modal, DeviceMappingModal, "Should instantiate as DeviceMappingModal")
	assert_is(modal, PopupPanel, "Should be a PopupPanel")

func test_lobby_root_script_compiles() -> void:
	var lobby_root: GDScript = load("res://scenes/menu/lobby/lobby_root.gd")
	assert_not_null(lobby_root, "lobby_root.gd should compile")

func test_open_mapping_builds_requested_columns() -> void:
	var modal = _build_modal(4)
	assert_eq(modal._columns.size(), 4, "Should build 4 columns")
	assert_true(modal._columns[0].is_occupied(), "Column 0 should hold MKB")
	assert_false(modal._columns[1].is_occupied(), "Column 1 should be empty")
	assert_string_contains(modal._columns[0].header_label.text, "Host", "Column 0 should be labeled host")

func test_open_mapping_renders_mkb_row() -> void:
	var modal = _build_modal(4)
	var row = modal._columns[0].get_device_row(LocalCoopManagerCode.MKB)
	assert_not_null(row, "MKB should be rendered in column 0")
	assert_eq(row.device_id, LocalCoopManagerCode.MKB)
	assert_false(row.movable, "MKB must not be movable")
	assert_eq(row.device_type, DeviceVisual.DeviceType.KEYBOARD_MOUSE)

func test_open_mapping_renders_gamepad_row() -> void:
	var modal = _build_modal(4, [0])
	var row = modal._columns[0].get_device_row(0)
	assert_not_null(row, "Gamepad 0 should be rendered")
	assert_true(row.movable, "Gamepad should be movable")
	assert_eq(row.device_type, DeviceVisual.DeviceType.GAMEPAD)

func test_move_requested_reparents_row() -> void:
	var modal = _build_modal(4, [0])
	modal._on_move_requested(0, 1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 1, "Gamepad 0 should be on seat 1")
	assert_not_null(modal._columns[1].get_device_row(0), "Row should be in column 1")
	assert_null(modal._columns[0].get_device_row(0), "Row should leave column 0")

func test_move_requested_ignores_mkb() -> void:
	var modal = _build_modal(4)
	modal._on_move_requested(LocalCoopManagerCode.MKB, 1)
	assert_eq(modal.coop_manager.get_player_for_device(LocalCoopManagerCode.MKB), 0, "MKB should stay on seat 0")

func test_move_requested_clamps_at_edges() -> void:
	var modal = _build_modal(4, [0])
	modal._on_move_requested(0, -1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 0, "Should clamp at column 0")
	modal._on_move_requested(0, 1)  # -> 1
	modal._on_move_requested(0, 1)  # -> 2
	modal._on_move_requested(0, 1)  # -> 3
	assert_eq(modal.coop_manager.get_player_for_device(0), 3, "Should reach last column")
	modal._on_move_requested(0, 1)  # clamp
	assert_eq(modal.coop_manager.get_player_for_device(0), 3, "Should clamp at last column")
