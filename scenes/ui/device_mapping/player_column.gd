class_name PlayerColumn
extends VBoxContainer

## One seat/slot in the mapping modal. seat_index == local_player_id.
##
## A dumb view: the modal pushes state in via [method setup], [method add_device_row],
## [method remove_device_row], and [method show_rejection].
## It owns its header, its device rows, and a rejection banner.

var seat_index: int = 0

@onready var header_label: Label = %HeaderLabel
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var rejection_label: Label = %RejectionLabel

## Configures the column for [param new_seat_index] (== local_player_id).
## Safe to call before or after entering the tree.
func setup(new_seat_index: int) -> void:
	seat_index = new_seat_index
	_refresh_header()

func _ready() -> void:
	_refresh_header()

func add_device_row(row: Control) -> void:
	rows_container.add_child(row)

func remove_device_row(device_id: int) -> void:
	var row := get_device_row(device_id)
	if row:
		rows_container.remove_child(row)
		row.queue_free()

## Returns the row for [param device_id], or null if none.
func get_device_row(device_id: int) -> Control:
	for child in rows_container.get_children():
		if _matches_device(child, device_id):
			return child as Control
	return null

func get_device_ids() -> Array[int]:
	var ids: Array[int] = []
	for child in rows_container.get_children():
		if child is DeviceRow:
			ids.append(child.device_id)
		elif child.has_meta("device_id"):
			ids.append(int(child.get_meta("device_id")))
	return ids

## True when at least one device is bound to this seat.
func is_occupied() -> bool:
	return rows_container.get_child_count() > 0

## Shows a rejection message on this column (e.g. "lobby full").
func show_rejection(reason: String) -> void:
	if rejection_label == null:
		return
	rejection_label.text = tr(reason)
	rejection_label.visible = true

func clear_rejection() -> void:
	if rejection_label == null:
		return
	rejection_label.text = ""
	rejection_label.visible = false

func _matches_device(node: Node, device_id: int) -> bool:
	if node is DeviceRow:
		return node.device_id == device_id
	if node.has_meta("device_id"):
		return int(node.get_meta("device_id")) == device_id
	return false

func _refresh_header() -> void:
	if header_label == null:
		return
	header_label.text = tr("P%d") % (seat_index + 1)
