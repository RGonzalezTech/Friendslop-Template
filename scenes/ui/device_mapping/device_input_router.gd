class_name DeviceInputRouter
extends RefCounted

## Interprets raw joypad input as "device N wants to move left/right".
##
## Extracted from the modal's old _unhandled_input. Pure logic, headless-testable
## with no UI. Applies an axis cooldown so a held stick doesn't spam moves.
##
## The modal feeds it every unhandled input event; it emits [signal move_intent]
## only when an event maps to a real move.

## Emitted with (device_id, direction) where direction is -1 (left) or +1 (right).
signal move_intent(device_id: int, direction: int)

const COOLDOWN_MS: int = 200
const AXIS_DEADZONE: float = 0.5

var cooldown_ms: int = COOLDOWN_MS
var _last_move_msec: Dictionary = {}  ## device_id -> Time.get_ticks_msec()

## Feeds one raw input event. Emits [signal move_intent] on a valid move.
func interpret(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	var direction := _direction_for(event)
	if direction == 0:
		return

	var device: int = event.device
	if not _cooldown_elapsed(device):
		return

	move_intent.emit(device, direction)

## Clears cooldown state so the same device can move again immediately.
func reset() -> void:
	_last_move_msec.clear()

func _direction_for(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		if not event.pressed:
			return 0
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT:
				return -1
			JOY_BUTTON_DPAD_RIGHT:
				return 1
			_:
				return 0
	if event is InputEventJoypadMotion:
		if event.axis != JOY_AXIS_LEFT_X:
			return 0
		if event.axis_value <= -AXIS_DEADZONE:
			return -1
		if event.axis_value >= AXIS_DEADZONE:
			return 1
	return 0

func _cooldown_elapsed(device: int) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _last_move_msec.get(device, 0)
	if now - last < cooldown_ms:
		return false
	_last_move_msec[device] = now
	return true
