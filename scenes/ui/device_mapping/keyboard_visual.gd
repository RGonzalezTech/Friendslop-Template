class_name KeyboardVisual
extends DeviceVisual

## Renders the mouse-and-keyboard device. Placeholder: a centered label.
## Swap for real art/animation without touching DeviceRow/PlayerColumn/Modal.

func _rebuild() -> void:
	_make_label("Keyboard + Mouse")
