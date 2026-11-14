extends GutTest

## Unit tests for the device-mapping building blocks:
## DeviceInputRouter, SeatSnapshot, PlayerColumn, DeviceRow, and LocalSeatCoordinator.

const COLUMN_SCENE := preload("res://scenes/ui/device_mapping/PlayerColumn.tscn")
const ROW_SCENE := preload("res://scenes/ui/device_mapping/DeviceRow.tscn")


class TestDeviceInputRouter:
	extends GutTest

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

	func test_ignores_non_joypad() -> void:
		var router := DeviceInputRouter.new()
		watch_signals(router)
		var key := InputEventKey.new()
		key.keycode = KEY_LEFT
		key.pressed = true
		assert_false(router.interpret(key))
		assert_signal_not_emitted(router.move_intent)

	func test_dpad_right_and_left_emit_move() -> void:
		var router := DeviceInputRouter.new()
		watch_signals(router)

		var right := InputEventJoypadButton.new()
		right.device = 0
		right.button_index = JOY_BUTTON_DPAD_RIGHT
		right.pressed = true
		assert_true(router.interpret(right))
		assert_signal_emitted_with_parameters(router.move_intent, [0, 1], 0)

		var left := InputEventJoypadButton.new()
		left.device = 2
		left.button_index = JOY_BUTTON_DPAD_LEFT
		left.pressed = true
		assert_true(router.interpret(left))
		assert_signal_emitted_with_parameters(router.move_intent, [2, -1], 1)

	func test_button_release_ignored() -> void:
		var router := DeviceInputRouter.new()
		watch_signals(router)

		var release := InputEventJoypadButton.new()
		release.device = 0
		release.button_index = JOY_BUTTON_DPAD_RIGHT
		release.pressed = false
		assert_false(router.interpret(release))

		assert_signal_not_emitted(router.move_intent)

	func test_stick_requires_return_to_center_between_moves() -> void:
		var router := DeviceInputRouter.new()
		watch_signals(router)

		var push := InputEventJoypadMotion.new()
		push.device = 0
		push.axis = JOY_AXIS_LEFT_X
		push.axis_value = 1.0
		assert_true(router.interpret(push))
		assert_signal_emit_count(router.move_intent, 1)
		assert_signal_emitted_with_parameters(router.move_intent, [0, 1])

		# Still held past deadzone — should NOT emit a second move.
		var held := InputEventJoypadMotion.new()
		held.device = 0
		held.axis = JOY_AXIS_LEFT_X
		held.axis_value = 0.85
		assert_true(router.interpret(held))
		assert_signal_emit_count(router.move_intent, 1)

		# Unrelated Y axis must NOT reset horizontal stick latch.
		var vertical := InputEventJoypadMotion.new()
		vertical.device = 0
		vertical.axis = JOY_AXIS_LEFT_Y
		vertical.axis_value = 0.0
		assert_false(router.interpret(vertical))

		var still_held := InputEventJoypadMotion.new()
		still_held.device = 0
		still_held.axis = JOY_AXIS_LEFT_X
		still_held.axis_value = 0.9
		assert_true(router.interpret(still_held))
		assert_signal_emit_count(router.move_intent, 1)

		# Return X axis to center, then push again -> emits move #2.
		var center := InputEventJoypadMotion.new()
		center.device = 0
		center.axis = JOY_AXIS_LEFT_X
		center.axis_value = 0.1
		assert_false(router.interpret(center))

		var push_again := InputEventJoypadMotion.new()
		push_again.device = 0
		push_again.axis = JOY_AXIS_LEFT_X
		push_again.axis_value = 0.95
		assert_true(router.interpret(push_again))
		assert_signal_emit_count(router.move_intent, 2)

	func test_stick_state_is_per_device() -> void:
		var router := DeviceInputRouter.new()
		watch_signals(router)

		var pad0 := InputEventJoypadMotion.new()
		pad0.device = 0
		pad0.axis = JOY_AXIS_LEFT_X
		pad0.axis_value = -1.0
		router.interpret(pad0)

		var pad1 := InputEventJoypadMotion.new()
		pad1.device = 1
		pad1.axis = JOY_AXIS_LEFT_X
		pad1.axis_value = -1.0
		router.interpret(pad1)

		assert_signal_emit_count(router.move_intent, 2)

	func test_custom_accept_and_cancel_actions() -> void:
		_register_joy_button_action(&"test_joy_accept", JOY_BUTTON_A)
		_register_joy_button_action(&"test_joy_cancel", JOY_BUTTON_B)

		var router := DeviceInputRouter.new()
		router.action_accept = &"test_joy_accept"
		router.action_cancel = &"test_joy_cancel"
		watch_signals(router)

		var accept := InputEventJoypadButton.new()
		accept.device = 1
		accept.button_index = JOY_BUTTON_A
		accept.pressed = true
		assert_true(router.interpret(accept))
		assert_signal_emitted_with_parameters(router.accept_intent, [1])

		var cancel := InputEventJoypadButton.new()
		cancel.device = 2
		cancel.button_index = JOY_BUTTON_B
		cancel.pressed = true
		assert_true(router.interpret(cancel))
		assert_signal_emitted_with_parameters(router.cancel_intent, [2])


class TestSeatSnapshot:
	extends GutTest

	var _manager: LocalCoopManagerCode

	func before_each() -> void:
		var mock = double(InputProvider).new()
		stub(mock, "get_connected_joypads").to_return([])
		_manager = LocalCoopManagerCode.new()
		_manager.input_provider = mock
		add_child_autofree(_manager)

	func test_capture_and_restore() -> void:
		_manager.bind_device(0, 1)
		var snap := SeatSnapshot.new()
		snap.capture(_manager)
		_manager.bind_device(0, 2)
		assert_eq(_manager.get_player_for_device(0), 2, "Sanity: device moved to slot 2")
		snap.restore(_manager)
		assert_eq(_manager.get_player_for_device(0), 1, "Restore should put device back on slot 1")

	func test_get_seat_defaults_to_primary() -> void:
		var snap := SeatSnapshot.new()
		snap.capture(_manager)
		assert_eq(snap.get_seat(99), LocalCoopManagerCode.PRIMARY_SLOT, "Unknown device defaults to primary slot")

	func test_restore_sends_hotplugged_pad_to_primary_slot() -> void:
		var snap := SeatSnapshot.new()
		snap.capture(_manager)

		# Pad 5 connected mid-modal and moved to seat 2
		_manager.bind_device(5, 2)
		snap.restore(_manager)

		assert_eq(_manager.get_player_for_device(5), LocalCoopManagerCode.PRIMARY_SLOT,
			"Hotplugged unknown pad should restore to seat 0")
		assert_true(5 in _manager.get_devices_for_player(0))

	func test_restore_does_not_rebind_unplugged_pad() -> void:
		_manager.bind_device(0, 1)
		var snap := SeatSnapshot.new()
		snap.capture(_manager)

		# Pad 0 unplugged mid-modal
		_manager.unbind_device(0)
		snap.restore(_manager)

		assert_false(0 in _manager.get_devices_for_player(1),
			"Unplugged pad must not be ghost-rebound on restore")
		assert_false(0 in _manager.get_devices_for_player(0),
			"Unplugged pad must remain unbound")


class TestPlayerColumn:
	extends GutTest

	func test_setup_sets_seat_and_p_label() -> void:
		var column := COLUMN_SCENE.instantiate() as PlayerColumn
		add_child_autofree(column)
		column.setup(0)
		assert_eq(column.seat_index, 0)
		assert_eq(column.header_label.text, "P1", "Seat 0 should be labeled P1")

		column.setup(2)
		assert_eq(column.seat_index, 2)
		assert_eq(column.header_label.text, "P3", "Seat 2 should be labeled P3")

	func test_occupancy_and_ids() -> void:
		var column := COLUMN_SCENE.instantiate() as PlayerColumn
		add_child_autofree(column)
		assert_false(column.is_occupied())

		var row := ROW_SCENE.instantiate() as DeviceRow
		column.add_device_row(row)
		row.setup(-1, false)

		var custom_row := Control.new()
		custom_row.set_meta("device_id", 2)
		column.add_device_row(custom_row)

		assert_true(column.is_occupied())
		assert_eq(column.get_device_ids(), [-1, 2])
		assert_not_null(column.get_device_row(-1))
		assert_eq(column.get_device_row(2), custom_row)
		assert_null(column.get_device_row(0))

	func test_show_and_clear_rejection() -> void:
		var column := COLUMN_SCENE.instantiate() as PlayerColumn
		add_child_autofree(column)
		assert_false(column.rejection_label.visible)
		column.show_rejection("lobby full")
		assert_true(column.rejection_label.visible)
		assert_string_contains(column.rejection_label.text, "lobby full")
		column.clear_rejection()
		assert_false(column.rejection_label.visible)


class TestDeviceRow:
	extends GutTest

	func test_setup_keyboard_identity() -> void:
		var row := ROW_SCENE.instantiate() as DeviceRow
		add_child_autofree(row)
		row.setup(-1, true)
		assert_eq(row.device_id, -1)
		assert_false(row.movable, "MKB should never be movable")
		assert_string_contains(row.name_label.text, "Keyboard")

	func test_setup_gamepad_identity() -> void:
		var row := ROW_SCENE.instantiate() as DeviceRow
		add_child_autofree(row)
		row.setup(0, true)
		assert_eq(row.device_id, 0)
		assert_true(row.movable)
		assert_string_contains(row.name_label.text, "Gamepad 0")


class TestLocalSeatCoordinator:
	extends GutTest

	var _coop: LocalCoopManagerCode
	var _lobby_container: Node
	var _mock_lobby: LobbyManagerCode
	var _coordinator: LocalSeatCoordinator

	func before_each() -> void:
		var input_mock = double(InputProvider).new()
		stub(input_mock, "get_connected_joypads").to_return([])
		_coop = LocalCoopManagerCode.new()
		_coop.input_provider = input_mock
		add_child_autofree(_coop)

		_lobby_container = Node.new()
		add_child_autofree(_lobby_container)
		var mp := SceneMultiplayer.new()
		get_tree().set_multiplayer(mp, _lobby_container.get_path())

		_mock_lobby = double(LobbyManagerCode).new()
		_lobby_container.add_child(_mock_lobby)
		var initial_host := Node.new()
		autofree(initial_host)
		stub(_mock_lobby, "get_local_players").to_return({0: initial_host})

		_coordinator = LocalSeatCoordinator.new(_coop, _mock_lobby)

	func after_each() -> void:
		if is_instance_valid(_lobby_container) and is_inside_tree():
			get_tree().set_multiplayer(null, _lobby_container.get_path())

	func test_compact_seats_removes_gaps_preserving_order() -> void:
		_coop.bind_device(0, 3)
		_coop.bind_device(1, 5)

		var compacted := _coordinator.compact_seats()

		assert_eq(compacted, [0, 1, 2])
		assert_eq(_coop.get_player_for_device(0), 1)
		assert_eq(_coop.get_player_for_device(1), 2)

	func test_commit_adds_compacted_seats_and_emits_committed() -> void:
		_coop.bind_device(0, 3)
		var existing_host := Node.new()
		autofree(existing_host)
		stub(_mock_lobby, "get_local_players").to_return({0: existing_host})

		watch_signals(_coordinator)
		_coordinator.commit()

		assert_eq(_coop.get_player_for_device(0), 1, "Seat 3 should compact to seat 1")
		assert_called(_mock_lobby.add_local_player.bind(1))
		assert_not_called(_mock_lobby.remove_local_player)
		assert_signal_not_emitted(_coordinator.committed, "Wait for player_joined before committed")

		# Unrelated peer joining should not resolve pending add
		_mock_lobby.player_joined.emit(99, 1)
		assert_signal_not_emitted(_coordinator.committed)

		# Local peer (id 1 in default OfflineMultiplayerPeer) resolves add
		_mock_lobby.player_joined.emit(1, 1)
		assert_signal_emitted(_coordinator.committed)

	func test_commit_removes_dropped_seats_without_adding() -> void:
		var dummy0 := Node.new()
		var dummy1 := Node.new()
		var dummy2 := Node.new()
		autofree(dummy0)
		autofree(dummy1)
		autofree(dummy2)
		stub(_mock_lobby, "get_local_players").to_return({0: dummy0, 1: dummy1, 2: dummy2})
		_coop.bind_device(0, 1)

		watch_signals(_coordinator)
		_coordinator.commit()

		assert_called(_mock_lobby.remove_local_player.bind(2))
		assert_not_called(_mock_lobby.add_local_player)
		assert_signal_emitted(_coordinator.committed)

	func test_commit_no_diff_emits_committed_immediately() -> void:
		var dummy0 := Node.new()
		var dummy1 := Node.new()
		autofree(dummy0)
		autofree(dummy1)
		stub(_mock_lobby, "get_local_players").to_return({0: dummy0, 1: dummy1})
		_coop.bind_device(0, 1)

		watch_signals(_coordinator)
		_coordinator.commit()

		assert_not_called(_mock_lobby.add_local_player)
		assert_not_called(_mock_lobby.remove_local_player)
		assert_signal_emitted(_coordinator.committed)

	func test_commit_rejection_reverts_only_rejected_seat() -> void:
		_coop.bind_device(0, 1)
		_coop.bind_device(1, 3)  # compacts to 2
		var dummy0 := Node.new()
		autofree(dummy0)
		stub(_mock_lobby, "get_local_players").to_return({0: dummy0})

		watch_signals(_coordinator)
		_coordinator.commit()

		assert_called(_mock_lobby.add_local_player.bind(1))
		assert_called(_mock_lobby.add_local_player.bind(2))

		_mock_lobby.player_joined.emit(1, 1)
		_mock_lobby.reject_add_player.emit(2, "lobby full")

		assert_eq(_coop.get_player_for_device(0), 1, "Accepted seat 1 should stay")
		assert_eq(_coop.get_player_for_device(1), 0, "Rejected seat 2 should revert to seat 0")
		assert_signal_emitted_with_parameters(_coordinator.seat_rejected, [2, "lobby full"])
		assert_signal_not_emitted(_coordinator.committed)

	func test_commit_rejection_moves_all_pads_on_rejected_seat_to_zero() -> void:
		_coop.bind_device(0, 1)
		_coop.bind_device(1, 1)
		var dummy0 := Node.new()
		autofree(dummy0)
		stub(_mock_lobby, "get_local_players").to_return({0: dummy0})

		watch_signals(_coordinator)
		_coordinator.commit()
		_mock_lobby.reject_add_player.emit(1, "lobby full")

		assert_eq(_coop.get_player_for_device(0), 0)
		assert_eq(_coop.get_player_for_device(1), 0)
		assert_signal_emitted_with_parameters(_coordinator.seat_rejected, [1, "lobby full"])
		assert_signal_not_emitted(_coordinator.committed)
