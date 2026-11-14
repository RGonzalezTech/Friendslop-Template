class_name DeviceRow
extends HBoxContainer

## A single physical input device in the mapping modal.
##
## A dumb view: renders an identity label and exposes [signal move_requested]
## so its own affordances (buttons/click UI in custom or default scenes) can
## request a column move.

## Emitted when the row's own UI requests a move: -1 (left) or +1 (right).
signal move_requested(direction: int)

const MKB_LABEL: String = "Keyboard + Mouse"

var device_id: int = -1
var movable: bool = false

@onready var name_label: Label = %NameLabel

## Configures the row: which device and whether it can move.
## Safe to call before or after the row enters the tree.
func setup(new_device_id: int, can_move: bool = true) -> void:
	device_id = new_device_id
	movable = can_move and new_device_id >= 0
	_refresh_label()

func get_device_id() -> int:
	return device_id

func _ready() -> void:
	_refresh_label()

func _refresh_label() -> void:
	if name_label == null:
		return
	name_label.text = tr(MKB_LABEL) if device_id < 0 else (tr("Gamepad %d") % device_id)
