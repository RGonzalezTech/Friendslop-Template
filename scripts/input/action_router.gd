extends Node
class_name ActionRouter

## This node is responsible for reading inputs and filtering them for a specific Device

## The int that represents mouse and keyboard (all others are gamepads)
const MKB: int = -1

## The int that represents an "all" type of input
const ALL: int = -2

## The device ID that this Input relay filters for
@export var device_id: int = ALL

## The list of action names to clone for this specific device
@export var actions_to_monitor: Array[String] = []

var _device_specific_action_names: Array[String] = []

## When an action is pressed _FOR THIS DEVICE_, emit the signal
signal action_detected(action_name: String, event: InputEvent)

## Checks if an input is a "Mouse+Keyboard" type
static func is_mkb(event: InputEvent) -> bool:
    var is_key := event is InputEventKey
    var is_mouse_btn := event is InputEventMouseButton
    var is_mouse_move := event is InputEventMouseMotion

    return is_key or is_mouse_btn or is_mouse_move

## Checks if an input is a "Joypad" type
static func is_joypad(event: InputEvent) -> bool:
    var is_joypad_btn := event is InputEventJoypadButton
    var is_joypad_move := event is InputEventJoypadMotion

    return is_joypad_btn or is_joypad_move

## Appends _device_ID to an action name
static func device_action_name(action: String, device: int) -> String:
    return "%s_device_%d" % [action, device]

## Reverse of device_action_name
static func base_action_from_device_action(device_action: String) -> String:
    var parts = device_action.rsplit("_device_", false, 1)
    if parts.size() == 2 and parts[1].is_valid_int():
        return parts[0]
    return device_action

## Sets up device-specific actions in InputMap based on the ActionRouter's device_id.
## For MKB, it copies keyboard/mouse events. For gamepads, it copies joypad events and sets the device ID.
func setup_device_specific_actions() -> void:
    _device_specific_action_names.clear()
    for base_action_name in actions_to_monitor:
        _clone_and_configure_device_action(base_action_name)

func _unhandled_input(event: InputEvent) -> void:
    for action_name in _device_specific_action_names:
        if not event.is_action(action_name, true):
            continue

        var base_action_name = base_action_from_device_action(action_name)
        action_detected.emit(base_action_name, event)
        if is_inside_tree():
            get_viewport().set_input_as_handled()
        return

## returns the specific action strength for this device
func get_strength(action: String) -> float:
    var target_action = action if device_id == ALL else device_action_name(action, device_id)
    return Input.get_action_strength(target_action)

## Returns the get-axis for device-specific 
func get_axis(left_action: String, right_action: String) -> float:
    var left = left_action if device_id == ALL else device_action_name(left_action, device_id)
    var right = right_action if device_id == ALL else device_action_name(right_action, device_id)

    return Input.get_axis(left, right)

func _ready() -> void:
    setup_device_specific_actions()

func _setup_mkb_actions(new_action_name: String, events_from_base_action: Array) -> void:
    for ev in events_from_base_action:
        if not is_mkb(ev):
            continue
        InputMap.action_add_event(new_action_name, ev)

func _setup_gamepad_actions(new_action_name: String, events_from_base_action: Array) -> void:
    for ev in events_from_base_action:
        if not is_joypad(ev):
            continue
        var new_ev = ev.duplicate()
        new_ev.device = device_id
        InputMap.action_add_event(new_action_name, new_ev)

func _clone_and_configure_device_action(base_action_name: String) -> void:
    # Safety Check: Ensure the base action actually exists before trying to clone it
    if not InputMap.has_action(base_action_name):
        push_warning("ActionRouter: Action '%s' not found in InputMap." % base_action_name)
        return

    if device_id == ALL:
        _device_specific_action_names.append(base_action_name)
        return

    var new_action_name = device_action_name(base_action_name, device_id)
    if not InputMap.has_action(new_action_name):
        InputMap.add_action(new_action_name)
    _device_specific_action_names.append(new_action_name)

    # Clear existing events for the device-specific action to avoid duplicates
    InputMap.action_erase_events(new_action_name)

    var events_from_base_action = InputMap.action_get_events(base_action_name)
    if device_id == MKB:
        _setup_mkb_actions(new_action_name, events_from_base_action)
    else:
        _setup_gamepad_actions(new_action_name, events_from_base_action)
