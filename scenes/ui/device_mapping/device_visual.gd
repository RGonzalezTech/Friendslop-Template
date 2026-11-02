class_name DeviceVisual
extends Control

## Abstract base for the visual rendering of a single input device.
##
## Subclasses own the *art*: a gamepad icon, a keyboard, background images,
## animations — and they react to [enum DeviceState] changes so the same art can
## be tinted/animated for idle, focused, or disabled.
##
## The contract (subclasses override the underscore methods, never the public
## ones):
##   setup(device_id)  ->  _rebuild()
##   set_state(state)  ->  _apply_state()
##
## This is the Open/Closed seam: adding a mouse/touch visual is a new subclass —
## no changes to [DeviceRow], [PlayerColumn], or [DeviceMappingModal].

enum DeviceType {
	KEYBOARD_MOUSE, ## device_id < 0 (LocalCoopManagerCode.MKB)
	GAMEPAD,        ## device_id >= 0
}

enum DeviceState {
	IDLE,     ## default; no special emphasis
	FOCUSED,  ## currently the highlight / move target
	DISABLED, ## shown but not interactive
}

var device_id: int = -1
var state: DeviceState = DeviceState.IDLE

## The label used by the default placeholder rendering. Real-art subclasses may
## leave this null and override [method _apply_state] entirely.
var _label: Label

## Builds (or rebuilds) the graphic for [param new_device_id]. Idempotent.
func setup(new_device_id: int) -> void:
	device_id = new_device_id
	_rebuild()

## Applies a state change. No-op when the state is unchanged.
func set_state(new_state: DeviceState) -> void:
	if new_state == state:
		return
	state = new_state
	_apply_state()

# ── virtual contract ────────────────────────────────────────────────────────

func _rebuild() -> void:
	pass

## Default rendering tints the placeholder label. Override for real art.
func _apply_state() -> void:
	if _label == null:
		return
	match state:
		DeviceState.FOCUSED:
			_label.modulate = Color.CYAN
		DeviceState.DISABLED:
			_label.modulate = Color(0.5, 0.5, 0.5, 0.6)
		_:
			_label.modulate = Color.WHITE

# ── helpers ─────────────────────────────────────────────────────────────────

## Creates (idempotently) a centered, expanding label for placeholder art, sets
## its text, and applies the current state. Returns the label.
func _make_label(text: String) -> Label:
	if _label == null:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_label)
	_label.text = text
	_apply_state()
	return _label
