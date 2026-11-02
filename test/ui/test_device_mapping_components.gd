extends GutTest

## Unit tests for the device-mapping building blocks: DeviceVisualFactory,
## DeviceInputRouter, SeatSnapshot, PlayerColumn, and DeviceRow.

const COLUMN_SCENE := preload("res://scenes/ui/device_mapping/PlayerColumn.tscn")
const ROW_SCENE := preload("res://scenes/ui/device_mapping/DeviceRow.tscn")


class TestDeviceVisualFactory:
	extends GutTest

	func test_type_for_device() -> void:
		assert_eq(DeviceVisualFactory.type_for_device(-1), DeviceVisual.DeviceType.KEYBOARD_MOUSE)
		assert_eq(DeviceVisualFactory.type_for_device(0), DeviceVisual.DeviceType.GAMEPAD)
		assert_eq(DeviceVisualFactory.type_for_device(3), DeviceVisual.DeviceType.GAMEPAD)

	func test_create_keyboard_visual() -> void:
		var factory = DeviceVisualFactory.new()
		var visual = factory.create(DeviceVisual.DeviceType.KEYBOARD_MOUSE)
		assert_is(visual, KeyboardVisual)
		visual.free()

	func test_create_gamepad_visual() -> void:
		var factory = DeviceVisualFactory.new()
		var visual = factory.create(DeviceVisual.DeviceType.GAMEPAD)
		assert_is(visual, GamepadVisual)
		visual.free()

	func test_register_override() -> void:
		var factory = DeviceVisualFactory.new()
		factory.register(DeviceVisual.DeviceType.GAMEPAD, func(): return KeyboardVisual.new())
		var visual = factory.create(DeviceVisual.DeviceType.GAMEPAD)
		assert_is(visual, KeyboardVisual, "Override should replace the default gamepad visual")
		visual.free()


class TestDeviceInputRouter:
	extends GutTest

	func test_ignores_non_joypad() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		router.interpret(InputEventKey.new())
		assert_signal_not_emitted(router.move_intent)

	func test_dpad_right_emits_move() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		var ev = InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = JOY_BUTTON_DPAD_RIGHT
		ev.pressed = true
		router.interpret(ev)
		assert_signal_emitted_with_parameters(router.move_intent, [0, 1])

	func test_dpad_left_emits_move() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		var ev = InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = JOY_BUTTON_DPAD_LEFT
		ev.pressed = true
		router.interpret(ev)
		assert_signal_emitted_with_parameters(router.move_intent, [0, -1])

	func test_button_release_ignored() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		var ev = InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = JOY_BUTTON_DPAD_RIGHT
		ev.pressed = false
		router.interpret(ev)
		assert_signal_not_emitted(router.move_intent)

	func test_axis_left_x_emits_move() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		var ev = InputEventJoypadMotion.new()
		ev.device = 0
		ev.axis = JOY_AXIS_LEFT_X
		ev.axis_value = 1.0
		router.interpret(ev)
		assert_signal_emitted_with_parameters(router.move_intent, [0, 1])

	func test_cooldown_suppresses_spam() -> void:
		var router = DeviceInputRouter.new()
		watch_signals(router)
		var ev = InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = JOY_BUTTON_DPAD_RIGHT
		ev.pressed = true
		router.interpret(ev)
		router.interpret(ev)  # same tick, within cooldown
		assert_signal_emit_count(router.move_intent, 1)


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
		var snap = SeatSnapshot.new()
		snap.capture(_manager)
		_manager.bind_device(0, 2)
		assert_eq(_manager.get_player_for_device(0), 2, "Sanity: device moved to slot 2")
		snap.restore(_manager)
		assert_eq(_manager.get_player_for_device(0), 1, "Restore should put device back on slot 1")

	func test_get_seat_defaults_to_primary() -> void:
		var snap = SeatSnapshot.new()
		snap.capture(_manager)
		assert_eq(snap.get_seat(99), LocalCoopManagerCode.PRIMARY_SLOT, "Unknown device defaults to primary slot")

	func test_add_and_get_seat() -> void:
		var snap = SeatSnapshot.new()
		snap.add(5, 3)
		assert_eq(snap.get_seat(5), 3)


class TestPlayerColumn:
	extends GutTest

	func test_setup_sets_seat_and_host() -> void:
		var column = COLUMN_SCENE.instantiate()
		add_child_autofree(column)
		column.setup(0, true)
		assert_eq(column.seat_index, 0)
		assert_true(column.is_host)
		assert_string_contains(column.header_label.text, "Host")

	func test_guest_header_has_no_host_tag() -> void:
		var column = COLUMN_SCENE.instantiate()
		add_child_autofree(column)
		column.setup(2, false)
		assert_false(column.is_host)
		assert_false(column.header_label.text.contains("Host"))

	func test_occupancy_and_ids() -> void:
		var column = COLUMN_SCENE.instantiate()
		add_child_autofree(column)
		assert_false(column.is_occupied())

		var row = ROW_SCENE.instantiate()
		var visual = KeyboardVisual.new()
		column.add_device_row(row)
		row.setup(-1, visual, false)

		assert_true(column.is_occupied())
		assert_eq(column.get_device_ids(), [-1])
		assert_not_null(column.get_device_row(-1))
		assert_null(column.get_device_row(0))

	func test_show_and_clear_rejection() -> void:
		var column = COLUMN_SCENE.instantiate()
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
		var row = ROW_SCENE.instantiate()
		add_child_autofree(row)
		row.setup(-1, KeyboardVisual.new(), false)
		assert_eq(row.device_id, -1)
		assert_eq(row.device_type, DeviceVisual.DeviceType.KEYBOARD_MOUSE)
		assert_false(row.movable)
		assert_string_contains(row.name_label.text, "Keyboard")

	func test_setup_gamepad_identity() -> void:
		var row = ROW_SCENE.instantiate()
		add_child_autofree(row)
		row.setup(0, GamepadVisual.new(), true)
		assert_eq(row.device_type, DeviceVisual.DeviceType.GAMEPAD)
		assert_true(row.movable)
		assert_string_contains(row.name_label.text, "Gamepad 0")

	func test_set_state_forwards_to_visual() -> void:
		var row = ROW_SCENE.instantiate()
		add_child_autofree(row)
		var visual = GamepadVisual.new()
		row.setup(0, visual, true)
		row.set_state(DeviceVisual.DeviceState.FOCUSED)
		assert_eq(visual.state, DeviceVisual.DeviceState.FOCUSED)
