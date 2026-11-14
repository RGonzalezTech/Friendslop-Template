extends GutTest

## Verifies DeviceMappingModal: Control overlay, custom row scenes, full
## re-render, out-of-range column growth, Submit/Cancel flows, and input routing.

const MODAL_SCENE := preload("res://scenes/ui/device_mapping/DeviceMappingModal.tscn")

var _temp_actions: Array[StringName] = []

func after_each() -> void:
	for action in _temp_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_temp_actions.clear()

func _register_joy_button_action(action_name: StringName, button: JoyButton) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name)
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)
	_temp_actions.append(action_name)

func _build_manager(gamepad_ids: Array[int] = []) -> LocalCoopManagerCode:
	var mock = double(InputProvider).new()
	stub(mock, "get_connected_joypads").to_return(gamepad_ids)
	var mgr := LocalCoopManagerCode.new()
	mgr.input_provider = mock
	add_child_autofree(mgr)
	return mgr

func _build_modal(player_count: int, gamepad_ids: Array[int] = []) -> DeviceMappingModal:
	var modal := MODAL_SCENE.instantiate() as DeviceMappingModal
	add_child_autofree(modal)
	modal.coop_manager = _build_manager(gamepad_ids)
	modal.open_mapping(player_count)
	return modal

func _make_custom_row_scene(node_name: String) -> PackedScene:
	var label := Label.new()
	label.name = node_name
	var packed := PackedScene.new()
	packed.pack(label)
	label.free()
	return packed

func test_modal_scene_loads_as_control_overlay() -> void:
	var scene: PackedScene = load("res://scenes/ui/device_mapping/DeviceMappingModal.tscn")
	assert_not_null(scene, "DeviceMappingModal.tscn should load")
	var modal := scene.instantiate()
	add_child_autofree(modal)
	assert_is(modal, DeviceMappingModal, "Should instantiate as DeviceMappingModal")
	assert_is(modal, Control, "Should be a Control overlay")
	assert_false(modal.visible, "Modal should start hidden before open_mapping()")

func test_lobby_root_script_compiles() -> void:
	var lobby_root: GDScript = load("res://scenes/menu/lobby/lobby_root.gd")
	assert_not_null(lobby_root, "lobby_root.gd should compile")

func test_open_mapping_builds_requested_columns_with_p_labels() -> void:
	var modal := _build_modal(4)
	assert_true(modal.visible)
	assert_eq(modal._columns.size(), 4, "Should build 4 columns")
	assert_true(modal._columns[0].is_occupied(), "Column 0 should hold MKB")
	assert_false(modal._columns[1].is_occupied(), "Column 1 should be empty")
	assert_eq(modal._columns[0].header_label.text, "P1", "Column 0 should be labeled P1")
	assert_eq(modal._columns[1].header_label.text, "P2", "Column 1 should be labeled P2")

func test_open_mapping_grows_columns_for_out_of_range_seat() -> void:
	var modal := MODAL_SCENE.instantiate() as DeviceMappingModal
	add_child_autofree(modal)
	var mgr := _build_manager([0])
	mgr.bind_device(0, 5)
	modal.coop_manager = mgr

	modal.open_mapping(4)

	assert_eq(modal._columns.size(), 6, "Column count should grow to max(4, 5 + 1)")
	assert_not_null(modal._columns[5].get_device_row(0), "Pad on seat 5 should be visible")

func test_custom_row_scenes_instantiated_per_device_type() -> void:
	var modal := MODAL_SCENE.instantiate() as DeviceMappingModal
	modal.keyboard_row_scene = _make_custom_row_scene("CustomKeyboardRow")
	modal.gamepad_row_scene = _make_custom_row_scene("CustomGamepadRow")
	add_child_autofree(modal)
	modal.coop_manager = _build_manager([0])

	modal.open_mapping(4)

	assert_eq(modal._columns[0].get_device_row(LocalCoopManagerCode.MKB).name, "CustomKeyboardRow")
	assert_eq(modal._columns[0].get_device_row(0).name, "CustomGamepadRow")

func test_rerenders_on_coop_signals() -> void:
	var modal := _build_modal(4, [0])
	modal.coop_manager.bind_device(0, 2)

	assert_null(modal._columns[0].get_device_row(0), "Pad 0 should leave column 0")
	assert_not_null(modal._columns[2].get_device_row(0), "Pad 0 should appear in column 2")

	modal.coop_manager.unbind_device(0)
	assert_null(modal._columns[2].get_device_row(0), "Unbound pad should disappear on re-render")

func test_move_requested_ignores_mkb() -> void:
	var modal := _build_modal(4)
	modal._on_move_requested(LocalCoopManagerCode.MKB, 1)
	assert_eq(modal.coop_manager.get_player_for_device(LocalCoopManagerCode.MKB), 0, "MKB should stay on seat 0")

func test_move_requested_clamps_at_edges() -> void:
	var modal := _build_modal(4, [0])
	modal._on_move_requested(0, -1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 0, "Should clamp at column 0")
	modal._on_move_requested(0, 1)  # -> 1
	modal._on_move_requested(0, 1)  # -> 2
	modal._on_move_requested(0, 1)  # -> 3
	assert_eq(modal.coop_manager.get_player_for_device(0), 3, "Should reach last column")
	modal._on_move_requested(0, 1)  # clamp
	assert_eq(modal.coop_manager.get_player_for_device(0), 3, "Should clamp at last column")

func test_row_move_requested_signal_updates_seat_cleanly() -> void:
	var modal := _build_modal(4, [0])
	var row := modal._columns[0].get_device_row(0) as DeviceRow
	row.move_requested.emit(1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 1)
	assert_not_null(modal._columns[1].get_device_row(0))
	await wait_process_frames(1)

func test_submit_stays_open_disables_input_and_closes_on_close() -> void:
	var modal := _build_modal(4, [0])
	watch_signals(modal)

	modal.submit_button.pressed.emit()

	assert_signal_emitted(modal.submitted)
	assert_true(modal.visible, "Modal should stay open while waiting for coordinator")
	assert_true(modal.submit_button.disabled, "Submit button should disable while pending")

	# Move input ignored while pending
	modal._on_move_requested(0, 1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 0, "Moves ignored while pending")

	modal.close()
	assert_false(modal.visible)
	assert_signal_not_emitted(modal.cancelled, "close() should not emit cancelled")

func test_ui_accept_submits_only_for_seat_0_device() -> void:
	_register_joy_button_action(&"test_modal_accept", JOY_BUTTON_A)
	var modal := _build_modal(4, [0, 1])
	modal.action_accept = &"test_modal_accept"
	modal.coop_manager.bind_device(1, 2)
	watch_signals(modal)

	var guest_accept := InputEventJoypadButton.new()
	guest_accept.device = 1
	guest_accept.button_index = JOY_BUTTON_A
	guest_accept.pressed = true
	modal._input(guest_accept)
	assert_signal_not_emitted(modal.submitted, "Guest device should not be able to submit")

	var host_accept := InputEventJoypadButton.new()
	host_accept.device = 0
	host_accept.button_index = JOY_BUTTON_A
	host_accept.pressed = true
	modal._input(host_accept)
	assert_signal_emitted(modal.submitted, "Seat 0 device should submit")

func test_cancel_button_restores_snapshot_and_emits_cancelled() -> void:
	var modal := _build_modal(4, [0])
	modal.coop_manager.bind_device(0, 2)
	watch_signals(modal)

	modal.cancel_button.pressed.emit()

	assert_eq(modal.coop_manager.get_player_for_device(0), 0, "Cancel should restore snapshot seat")
	assert_false(modal.visible)
	assert_signal_emitted(modal.cancelled)

func test_ui_cancel_action_cancels_from_keyboard_and_joypad() -> void:
	var modal := _build_modal(4, [0])
	modal.coop_manager.bind_device(0, 2)
	watch_signals(modal)

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	modal._input(esc)

	assert_eq(modal.coop_manager.get_player_for_device(0), 0)
	assert_false(modal.visible)
	assert_signal_emitted(modal.cancelled)

	# Re-open and test joypad cancel action
	_register_joy_button_action(&"test_modal_cancel", JOY_BUTTON_B)
	modal.action_cancel = &"test_modal_cancel"
	modal.open_mapping(4)
	modal.coop_manager.bind_device(0, 3)

	var pad_cancel := InputEventJoypadButton.new()
	pad_cancel.device = 0
	pad_cancel.button_index = JOY_BUTTON_B
	pad_cancel.pressed = true
	modal._input(pad_cancel)

	assert_eq(modal.coop_manager.get_player_for_device(0), 0)
	assert_false(modal.visible)
	assert_signal_emit_count(modal.cancelled, 2)

func test_backdrop_click_cancels_and_restores_snapshot() -> void:
	var modal := _build_modal(4, [0])
	modal.coop_manager.bind_device(0, 2)
	watch_signals(modal)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	modal.backdrop.gui_input.emit(click)

	assert_eq(modal.coop_manager.get_player_for_device(0), 0)
	assert_false(modal.visible)
	assert_signal_emitted(modal.cancelled)

func test_cancel_restores_hotplugged_to_seat_0_and_skips_unplugged() -> void:
	var modal := _build_modal(4, [0])
	# Mid-modal: pad 0 unplugged, pad 1 hotplugged and moved to seat 2
	modal.coop_manager.unbind_device(0)
	modal.coop_manager.bind_device(1, 2)

	modal.cancel()

	assert_false(0 in modal.coop_manager.get_devices_for_player(0), "Unplugged pad stays unbound")
	assert_eq(modal.coop_manager.get_player_for_device(1), 0, "Hotplugged pad resets to seat 0")

func test_show_rejection_displays_on_column_and_reenables_input() -> void:
	var modal := _build_modal(4, [0])
	modal.submit_button.pressed.emit()
	assert_true(modal.submit_button.disabled)

	modal.show_rejection(2, "lobby full")

	assert_false(modal.submit_button.disabled, "Rejection should re-enable submit")
	assert_true(modal._columns[2].rejection_label.visible)
	assert_string_contains(modal._columns[2].rejection_label.text, "lobby full")

	modal._on_move_requested(0, 1)
	assert_eq(modal.coop_manager.get_player_for_device(0), 1, "Moves should work again after rejection")
