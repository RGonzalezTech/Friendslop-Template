class_name GamepadVisual
extends DeviceVisual

## Renders a gamepad device. Placeholder: a centered label with the id.
## Swap for real gamepad art/animation without touching its neighbors.

func _rebuild() -> void:
	_make_label("Gamepad %d" % device_id)
