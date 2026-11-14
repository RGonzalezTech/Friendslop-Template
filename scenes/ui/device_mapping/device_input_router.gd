class_name DeviceInputRouter
extends RefCounted

## Interprets joypad input actions as edge-triggered per-device navigation intents.
##
## Pure logic, headless-testable with no UI. Reads configurable input actions
## (defaulting to Godot's built-in UI actions) and tracks stick return-to-center
## per device so a held stick does not repeat moves.

## Emitted with (device_id, direction) where direction is -1 (left) or +1 (right).
signal move_intent(device_id: int, direction: int)

## Emitted when a joypad device presses [member action_accept].
signal accept_intent(device_id: int)

## Emitted when a joypad device presses [member action_cancel].
signal cancel_intent(device_id: int)

var action_left: StringName = &"ui_left"
var action_right: StringName = &"ui_right"
var action_accept: StringName = &"ui_accept"
var action_cancel: StringName = &"ui_cancel"

var _stick_direction: Dictionary = {}  ## device_id -> int (-1, 0, or +1)

## Clears stick state so every device must return to center / start fresh.
func reset() -> void:
	_stick_direction.clear()

## Interprets a single input event. Returns true when the event is a joypad
## action handled (or held on axis) by this router.
func interpret(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false

	if event is InputEventJoypadButton:
		return _interpret_button(event)

	return _interpret_motion(event)

func _interpret_button(event: InputEventJoypadButton) -> bool:
	if not event.pressed or event.is_echo():
		return false

	var device: int = event.device
	if _is_action_pressed(event, action_left):
		move_intent.emit(device, -1)
		return true
	if _is_action_pressed(event, action_right):
		move_intent.emit(device, 1)
		return true
	if _is_action_pressed(event, action_accept):
		accept_intent.emit(device)
		return true
	if _is_action_pressed(event, action_cancel):
		cancel_intent.emit(device)
		return true
	return false

func _interpret_motion(event: InputEventJoypadMotion) -> bool:
	var dir: int = 0
	if _is_action_pressed(event, action_left):
		dir = -1
	elif _is_action_pressed(event, action_right):
		dir = 1

	var device: int = event.device
	if dir == 0:
		if _is_move_axis(event):
			_stick_direction[device] = 0
		return false

	var prev: int = _stick_direction.get(device, 0)
	if prev == dir:
		return true

	_stick_direction[device] = dir
	move_intent.emit(device, dir)
	return true

func _is_action_pressed(event: InputEvent, action: StringName) -> bool:
	if event.is_action_pressed(action):
		return true
	# Godot's built-in ui_* actions bind joypad events with device=0 instead of
	# DEVICE_ID_ALL (-1). Allow any joypad device to trigger those actions too.
	if event.device != 0:
		var normalized := event.duplicate() as InputEvent
		normalized.device = 0
		return normalized.is_action_pressed(action)
	return false

func _is_move_axis(event: InputEventJoypadMotion) -> bool:
	for action in [action_left, action_right]:
		if not InputMap.has_action(action):
			continue
		for mapped_event in InputMap.action_get_events(action):
			if mapped_event is InputEventJoypadMotion and mapped_event.axis == event.axis:
				return true
	return false
