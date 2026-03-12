extends ActionRouter
class_name GameActionRouter2D

enum LookSource {MOUSE, ACTION}

## The current source of look/peek input.
var current_look_source: LookSource = LookSource.MOUSE

func _init() -> void:
	actions_to_monitor = [
		"move_left",
		"move_right",
		"move_up",
		"move_down",
		"look_left",
		"look_right",
		"look_up",
		"look_down",
	]

func _input(event: InputEvent) -> void:
	if device_id != ALL:
		return
		
	_check_look_source(event)

# Determines if we are getting look input from the mouse or key/joypad inputs.
func _check_look_source(event: InputEvent) -> void:
	if is_joypad(event) or (event is InputEventKey and not event.is_echo()):
		# Check if this event corresponds to a look action
		for action in ["look_left", "look_right", "look_up", "look_down"]:
			if event.is_action(action):
				current_look_source = LookSource.ACTION
				break
	elif event is InputEventMouseMotion:
		current_look_source = LookSource.MOUSE

## Returns the current look direction normalized to [-1, 1] range.
## Automatically handles Mouse vs. Action source based on recent input.
func get_look_direction() -> Vector2:
	if current_look_source == LookSource.ACTION:
		var horizontal = get_axis("look_left", "look_right")
		var vertical = get_axis("look_up", "look_down")
		return Vector2(horizontal, vertical)
	else:
		# Mouse peeking logic
		var viewport := get_viewport()
		if not viewport:
			return Vector2.ZERO
			
		var half_size := viewport.get_visible_rect().size / 2.0
		var mouse_pos := viewport.get_mouse_position()
		
		# Get mouse position relative to center of screen normalized to [-1, 1]
		var offset_normalized := (mouse_pos - half_size) / half_size
		
		# Clamp to ensure it doesn't go too far
		return offset_normalized.clamp(-Vector2.ONE, Vector2.ONE)
