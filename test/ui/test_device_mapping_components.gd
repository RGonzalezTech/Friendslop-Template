extends GutTest

## Unit tests for the device-mapping building blocks:
## DeviceInputRouter and SeatSnapshot.


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
