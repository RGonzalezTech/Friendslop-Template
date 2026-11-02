class_name PlayerColumn
extends VBoxContainer

## One seat/slot in the mapping modal. seat_index == local_player_id.
##
## A dumb view: the modal pushes state in via [method setup], [method add_device_row],
## [method remove_device_row], [method set_state], and [method show_rejection].
## It owns its header, its device rows, and a rejection banner.

enum SlotState {
	EMPTY,   ## no devices bound
	ACTIVE,  ## >= 1 device bound
	FOCUSED, ## currently the highlighted move target
}

var seat_index: int = 0
var is_host: bool = false
var state: SlotState = SlotState.EMPTY

@onready var header_label: Label = %HeaderLabel
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var rejection_label: Label = %RejectionLabel

## Configures the column for [param new_seat_index] (== local_player_id) and
## whether it is the host seat. Safe to call before or after entering the tree.
func setup(new_seat_index: int, host: bool) -> void:
	seat_index = new_seat_index
	is_host = host
	_refresh_header()

func _ready() -> void:
	_refresh_header()
	_apply_state()

func add_device_row(row: DeviceRow) -> void:
	rows_container.add_child(row)

func remove_device_row(device_id: int) -> void:
	var row := get_device_row(device_id)
	if row:
		row.queue_free()

## Returns the row for [param device_id], or null if none.
func get_device_row(device_id: int) -> DeviceRow:
	for child in rows_container.get_children():
		if child is DeviceRow and child.device_id == device_id:
			return child
	return null

func get_device_ids() -> Array[int]:
	var ids: Array[int] = []
	for child in rows_container.get_children():
		if child is DeviceRow:
			ids.append(child.device_id)
	return ids

## True when at least one device is bound to this seat. Drives Submit.
func is_occupied() -> bool:
	return rows_container.get_child_count() > 0

## Applies a slot-state change (toggles header emphasis). No-op if unchanged.
func set_state(new_state: SlotState) -> void:
	if new_state == state:
		return
	state = new_state
	_apply_state()

## Shows a rejection message on this column (e.g. "lobby full").
func show_rejection(reason: String) -> void:
	if rejection_label == null:
		return
	rejection_label.text = "Rejected: %s" % reason
	rejection_label.visible = true

func clear_rejection() -> void:
	if rejection_label == null:
		return
	rejection_label.text = ""
	rejection_label.visible = false

func _refresh_header() -> void:
	if header_label == null:
		return
	var display_number: int = seat_index + 1  # humans count seats from 1
	header_label.text = "Seat %d (Host)" % display_number if is_host else "Seat %d" % display_number

func _apply_state() -> void:
	if header_label == null:
		return
	match state:
		SlotState.ACTIVE:
			header_label.modulate = Color.WHITE
		SlotState.FOCUSED:
			header_label.modulate = Color.CYAN
		_:
			header_label.modulate = Color(0.6, 0.6, 0.6)
