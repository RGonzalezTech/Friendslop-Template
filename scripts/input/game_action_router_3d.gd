extends ActionRouter
class_name GameActionRouter3D

## A 3D-focused Action Router for first/third-person games.
## Handles mouse-captured look (FPS-style), joypad stick look,
## movement direction, jumping, and sprinting.
## Inspired by Brackeys' ProtoController but separated from physics
## to stay consistent with the Action Router pattern.

enum LookSource { MOUSE, ACTION }

## The current source of look input (mouse delta vs. right stick / keys).
var current_look_source: LookSource = LookSource.MOUSE

## Whether the mouse is currently captured for FPS-style look.
var mouse_captured: bool = false

## Accumulated mouse delta this frame (reset every physics tick).
var _mouse_delta: Vector2 = Vector2.ZERO

## Look sensitivity applied to mouse delta (radians per pixel).
@export var mouse_look_sensitivity: float = 0.002

## Look sensitivity multiplier for action-based (stick/key) look input.
@export var action_look_sensitivity: float = 3.0

## Maximum pitch angle in degrees (clamped to avoid gimbal flip).
@export_range(1.0, 89.0) var max_pitch_degrees: float = 85.0

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
		"jump",
		"sprint",
	]

func _input(event: InputEvent) -> void:
	if device_id != ALL:
		return

	_check_look_source(event)
	_accumulate_mouse_delta(event)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)

	# Capture mouse on left-click, release on Escape
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		capture_mouse()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		release_mouse()

## Accumulates mouse motion for this frame while the mouse is captured.
func _accumulate_mouse_delta(event: InputEvent) -> void:
	if mouse_captured and event is InputEventMouseMotion:
		_mouse_delta += event.relative

## Determines if we are getting look input from the mouse or key/joypad inputs.
func _check_look_source(event: InputEvent) -> void:
	if is_joypad(event) or (event is InputEventKey and not event.is_echo()):
		for look_action in ["look_left", "look_right", "look_up", "look_down"]:
			if event.is_action(look_action):
				current_look_source = LookSource.ACTION
				break
	elif event is InputEventMouseMotion:
		current_look_source = LookSource.MOUSE

# -- Public API ----------------------------------------------------------------

## Returns the movement input as a 2D vector (x = left/right, y = forward/back).
## Suitable for constructing a 3D direction via the character's basis.
func get_move_direction() -> Vector2:
	var horizontal := get_axis("move_left", "move_right")
	var vertical := get_axis("move_up", "move_down")
	return Vector2(horizontal, vertical)

## Returns the look input for this frame as a Vector2.
## x = yaw (left/right), y = pitch (up/down).
## For MOUSE source: returns the accumulated mouse delta scaled by sensitivity.
## For ACTION source: returns the stick/key axis values scaled by sensitivity.
## Call this once per frame (in _physics_process) and reset afterwards with consume_look_input().
func get_look_input() -> Vector2:
	if current_look_source == LookSource.MOUSE:
		return _mouse_delta * mouse_look_sensitivity
	else:
		var horizontal := get_axis("look_left", "look_right")
		var vertical := get_axis("look_up", "look_down")
		return Vector2(horizontal, vertical) * action_look_sensitivity

## Resets the accumulated mouse delta. Call after processing look input each frame.
func consume_look_input() -> void:
	_mouse_delta = Vector2.ZERO

## Returns true if the jump action is currently held down.
func is_jump_pressed() -> bool:
	var action := "jump" if device_id == ALL else device_action_name("jump", device_id)
	return Input.is_action_pressed(action)

## Returns true if the jump action was just pressed this frame.
func is_jump_just_pressed() -> bool:
	var action := "jump" if device_id == ALL else device_action_name("jump", device_id)
	return Input.is_action_just_pressed(action)

## Returns true if the sprint action is currently held down.
func is_sprint_pressed() -> bool:
	var action := "sprint" if device_id == ALL else device_action_name("sprint", device_id)
	return Input.is_action_pressed(action)

## Returns true if the sprint action was just pressed this frame.
func is_sprint_just_pressed() -> bool:
	var action := "sprint" if device_id == ALL else device_action_name("sprint", device_id)
	return Input.is_action_just_pressed(action)

## Returns the max pitch in radians (convenience for clamping in the player script).
func get_max_pitch_rad() -> float:
	return deg_to_rad(max_pitch_degrees)

## Captures the mouse cursor for FPS-style look.
func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

## Releases the mouse cursor.
func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
