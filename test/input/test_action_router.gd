extends GutTest

var device: ActionRouter

func before_each():
    device = ActionRouter.new()

func after_each():
    device.free()

func test_is_mkb():
    # Test cases for keyboard events
    var key_event = InputEventKey.new()
    key_event.set_pressed(true)
    assert_true(ActionRouter.is_mkb(key_event), "InputEventKey should be MKB")

    # Test cases for mouse button events
    var mouse_btn_event = InputEventMouseButton.new()
    mouse_btn_event.set_pressed(true)
    assert_true(ActionRouter.is_mkb(mouse_btn_event), "InputEventMouseButton should be MKB")

    # Test cases for mouse motion events
    var mouse_motion_event = InputEventMouseMotion.new()
    assert_true(ActionRouter.is_mkb(mouse_motion_event), "InputEventMouseMotion should be MKB")

    # Test cases for non-MKB events (Joypad)
    var joy_btn_event = InputEventJoypadButton.new()
    joy_btn_event.set_pressed(true)
    assert_false(ActionRouter.is_mkb(joy_btn_event), "InputEventJoypadButton should not be MKB")

    var joy_motion_event = InputEventJoypadMotion.new()
    assert_false(ActionRouter.is_mkb(joy_motion_event), "InputEventJoypadMotion should not be MKB")

func test_is_joypad():
    # Test cases for joypad button events
    var joy_btn_event = InputEventJoypadButton.new()
    joy_btn_event.set_pressed(true)
    assert_true(ActionRouter.is_joypad(joy_btn_event), "InputEventJoypadButton should be Joypad")

    # Test cases for joypad motion events
    var joy_motion_event = InputEventJoypadMotion.new()
    assert_true(ActionRouter.is_joypad(joy_motion_event), "InputEventJoypadMotion should be Joypad")

    # Test cases for non-Joypad events (MKB)
    var key_event = InputEventKey.new()
    key_event.set_pressed(true)
    assert_false(ActionRouter.is_joypad(key_event), "InputEventKey should not be Joypad")

    var mouse_btn_event = InputEventMouseButton.new()
    mouse_btn_event.set_pressed(true)
    assert_false(ActionRouter.is_joypad(mouse_btn_event), "InputEventMouseButton should not be Joypad")

    var mouse_motion_event = InputEventMouseMotion.new()
    assert_false(ActionRouter.is_joypad(mouse_motion_event), "InputEventMouseMotion should not be Joypad")

func test_device_action_name():
    assert_eq(ActionRouter.device_action_name("attack", -1), "attack_device_-1")
    assert_eq(ActionRouter.device_action_name("jump", 0), "jump_device_0")
    assert_eq(ActionRouter.device_action_name("interact", 4), "interact_device_4")

func test_base_action_from_device_action():
    assert_eq(ActionRouter.base_action_from_device_action("attack_device_-1"), "attack")
    assert_eq(ActionRouter.base_action_from_device_action("jump_device_0"), "jump")
    assert_eq(ActionRouter.base_action_from_device_action("interact_device_4"), "interact")
    assert_eq(ActionRouter.base_action_from_device_action("some_action_without_device_id"), "some_action_without_device_id")

func test_ready_sets_up_input_map():
    # Setup for MKB
    var mkb_action_name = "test_mkb_action"
    var mkb_key_event = InputEventKey.new()
    mkb_key_event.keycode = KEY_A
    InputMap.add_action(mkb_action_name)
    InputMap.action_add_event(mkb_action_name, mkb_key_event)

    device.device_id = ActionRouter.MKB
    device.actions_to_monitor = [mkb_action_name]
    device._ready() # Simulate _ready() call

    var mkb_device_action_name = ActionRouter.device_action_name(mkb_action_name, ActionRouter.MKB)
    assert_true(InputMap.has_action(mkb_device_action_name), "MKB device-specific action should be added")
    assert_eq(device._device_specific_action_names[0], mkb_device_action_name, "MKB device-specific action name should be in _device_specific_action_names")
    var mkb_events = InputMap.action_get_events(mkb_device_action_name)
    assert_eq(mkb_events.size(), 1, "MKB device-specific action should have 1 event")
    assert_true(mkb_events[0] is InputEventKey, "MKB event should be InputEventKey")
    assert_eq(mkb_events[0].keycode, KEY_A, "MKB event keycode should match")

    # Setup for Gamepad
    var gamepad_action_name = "test_gamepad_action"
    var gamepad_button_event = InputEventJoypadButton.new()
    gamepad_button_event.button_index = JOY_BUTTON_A
    InputMap.add_action(gamepad_action_name)
    InputMap.action_add_event(gamepad_action_name, gamepad_button_event)

    device.device_id = 4 # Gamepad device ID
    device.actions_to_monitor = [gamepad_action_name]
    device._ready() # Simulate _ready() call

    var gamepad_device_action_name = ActionRouter.device_action_name(gamepad_action_name, 4)
    assert_true(InputMap.has_action(gamepad_device_action_name), "Gamepad device-specific action should be added")
    assert_true(device._device_specific_action_names.has(gamepad_device_action_name), "Gamepad device-specific action name should be in _device_specific_action_names")
    var gamepad_events = InputMap.action_get_events(gamepad_device_action_name)
    assert_eq(gamepad_events.size(), 1, "Gamepad device-specific action should have 1 event")
    assert_true(gamepad_events[0] is InputEventJoypadButton, "Gamepad event should be InputEventJoypadButton")
    assert_eq(gamepad_events[0].button_index, JOY_BUTTON_A, "Gamepad event button index should match")
    assert_eq(gamepad_events[0].device, 4, "Gamepad event device ID should match")

    # Cleanup InputMap
    InputMap.erase_action(mkb_action_name)
    InputMap.erase_action(mkb_device_action_name)
    InputMap.erase_action(gamepad_action_name)
    InputMap.erase_action(gamepad_device_action_name)

func test_all_mode():
    var action_name = "test_all_action"
    var other_action = "other_action"
    InputMap.add_action(action_name)
    InputMap.add_action(other_action)
    
    device.device_id = ActionRouter.ALL
    device.actions_to_monitor = [action_name]
    add_child_autofree(device)
    
    # 1. Verify _device_specific_action_names contains ONLY the base action
    assert_eq(device._device_specific_action_names.size(), 1)
    assert_eq(device._device_specific_action_names[0], action_name)
    
    # 2. Verify NO device-specific action was created in InputMap
    var device_action = ActionRouter.device_action_name(action_name, ActionRouter.ALL)
    assert_false(InputMap.has_action(device_action), "Should not create device-specific action in ALL mode")
    
    # 3. Verify _unhandled_input emits correct signal for monitored action
    watch_signals(device)
    var event = InputEventKey.new()
    event.keycode = KEY_SPACE
    InputMap.action_add_event(action_name, event)
    
    device._unhandled_input(event)
    assert_signal_emitted_with_parameters(device.action_detected, [action_name, event])
    
    # 4. Verify _unhandled_input does NOT emit signal for non-monitored action
    var other_event = InputEventKey.new()
    other_event.keycode = KEY_ESCAPE
    InputMap.action_add_event(other_action, other_event)
    
    device._unhandled_input(other_event)
    assert_signal_emit_count(device.action_detected, 1, "Signal should NOT have emitted for non-monitored action")
    
    # 5. Verify get_strength and get_axis pass-through logic
    # We can't mock Input, but we can verify they don't crash and return reasonable values
    # If they used device_action_name, they would likely return 0.0 because those actions don't exist
    assert_typeof(device.get_strength(action_name), TYPE_FLOAT)
    assert_typeof(device.get_axis(action_name, other_action), TYPE_FLOAT)
    
    # Cleanup
    InputMap.erase_action(action_name)
    InputMap.erase_action(other_action)