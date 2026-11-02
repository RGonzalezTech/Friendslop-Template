class_name DeviceRow
extends HBoxContainer

## A single physical input device in the mapping modal.
##
## A dumb view: it renders a [DeviceVisual] (the art) plus an identity label, and
## exposes [signal move_requested] so its own affordances (future click/button
## UI) can request a column move. It knows nothing about LocalCoopManager,
## LobbyManager, or the modal — all state is pushed in via [method setup] and
## [method set_state].

## Emitted when the row's own UI requests a move: -1 (left) or +1 (right).
## The modal routes this the same way it routes joypad input.
signal move_requested(direction: int)

const MKB_LABEL: String = "Keyboard + Mouse"

var device_id: int = -1
var device_type: DeviceVisual.DeviceType = DeviceVisual.DeviceType.KEYBOARD_MOUSE
var movable: bool = false

@onready var visual_slot: Control = %VisualSlot
@onready var name_label: Label = %NameLabel

var _visual: DeviceVisual

## Configures the row: which device, its visual art, and whether it can move.
## Safe to call before or after the row enters the tree.
func setup(new_device_id: int, visual: DeviceVisual, can_move: bool) -> void:
	device_id = new_device_id
	device_type = DeviceVisualFactory.type_for_device(new_device_id)
	movable = can_move
	_visual = visual
	_refresh_label()
	if is_node_ready():
		_mount_visual()

## Forwards a state change to the visual.
func set_state(new_state: DeviceVisual.DeviceState) -> void:
	if _visual:
		_visual.set_state(new_state)

func get_device_id() -> int:
	return device_id

func _ready() -> void:
	_refresh_label()
	_mount_visual()

## Adds the visual into its slot and sets it up. Idempotent.
func _mount_visual() -> void:
	if _visual == null or _visual.get_parent() != null:
		return
	visual_slot.add_child(_visual)
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.setup(device_id)

func _refresh_label() -> void:
	if name_label == null:
		return
	name_label.text = MKB_LABEL if device_id < 0 else ("Gamepad %d" % device_id)
