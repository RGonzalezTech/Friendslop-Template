class_name DeviceMappingModal
extends Control

## Overlay modal for assigning local input devices to seats.
##
## Knows only about [LocalCoopManagerCode]; emits [signal submitted] and
## [signal cancelled] so a caller can coordinate with the lobby and close
## the modal via [method close].

## Emitted when the user submits the current mapping. The modal stays open
## with Submit/move input disabled until [method close] or [method show_rejection].
signal submitted

## Emitted when the user cancels via Cancel button, cancel action, or backdrop click.
signal cancelled

const PLAYER_COLUMN_SCENE: PackedScene = preload("res://scenes/ui/device_mapping/PlayerColumn.tscn")
const DEFAULT_ROW_SCENE: PackedScene = preload("res://scenes/ui/device_mapping/DeviceRow.tscn")

@export var column_count: int = 4
@export var gamepad_row_scene: PackedScene = DEFAULT_ROW_SCENE
@export var keyboard_row_scene: PackedScene = DEFAULT_ROW_SCENE
@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_accept: StringName = &"ui_accept"
@export var action_cancel: StringName = &"ui_cancel"

@onready var backdrop: Control = %Backdrop
@onready var seat_columns: HBoxContainer = %SeatColumns
@onready var submit_button: Button = %SubmitButton
@onready var cancel_button: Button = %CancelButton

## Dependency seam — defaults to the autoload, injectable in tests.
var coop_manager: LocalCoopManagerCode = LocalCoopManager

var input_router: DeviceInputRouter = DeviceInputRouter.new()

var _columns: Array[PlayerColumn] = []
var _snapshot: SeatSnapshot = SeatSnapshot.new()
var _pending: bool = false
var _is_open: bool = false
var _active_signal_row: Control = null

func _ready() -> void:
	submit_button.pressed.connect(_on_submit)
	cancel_button.pressed.connect(_on_cancel)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	input_router.move_intent.connect(_on_move_requested)
	input_router.accept_intent.connect(_on_accept_intent)
	input_router.cancel_intent.connect(_on_cancel_intent)

func _exit_tree() -> void:
	_unsubscribe_coop()

#region Public API

## Opens the modal: captures a snapshot, subscribes to [member coop_manager],
## renders all seat columns, and shows the overlay.
func open_mapping(player_count: int = -1) -> void:
	if player_count > 0:
		column_count = player_count

	_pending = false
	_is_open = true
	if submit_button:
		submit_button.disabled = false

	_sync_router_actions()
	input_router.reset()
	_snapshot.capture(coop_manager)
	_subscribe_coop()
	_render()
	show()

## Displays a rejection banner on [param seat] and re-enables Submit/move input.
func show_rejection(seat: int, reason: String) -> void:
	_pending = false
	if submit_button:
		submit_button.disabled = false
	if seat >= 0 and seat < _columns.size():
		_columns[seat].show_rejection(reason)

## Closes the modal without emitting [signal cancelled].
func close() -> void:
	_is_open = false
	_pending = false
	_unsubscribe_coop()
	hide()

## Cancels mapping: restores snapshot, closes the modal, and emits [signal cancelled].
func cancel() -> void:
	_on_cancel()

#endregion

#region Rendering

func _render() -> void:
	if not is_instance_valid(coop_manager) or seat_columns == null:
		return

	var total_columns: int = maxi(column_count, 1)
	for slot in coop_manager.get_active_slots():
		total_columns = maxi(total_columns, slot + 1)

	for child in seat_columns.get_children():
		if is_instance_valid(_active_signal_row) and child.is_ancestor_of(_active_signal_row):
			var row_parent := _active_signal_row.get_parent()
			if row_parent:
				row_parent.remove_child(_active_signal_row)
			_active_signal_row.queue_free()
		seat_columns.remove_child(child)
		child.free()
	_columns.clear()

	for seat in range(total_columns):
		var column := PLAYER_COLUMN_SCENE.instantiate() as PlayerColumn
		seat_columns.add_child(column)
		column.setup(seat)
		_columns.append(column)
		for device in coop_manager.get_devices_for_player(seat):
			_add_row_to_column(column, device)

func _add_row_to_column(column: PlayerColumn, device_id: int) -> void:
	var scene := keyboard_row_scene if device_id < 0 else gamepad_row_scene
	if scene == null:
		scene = DEFAULT_ROW_SCENE
	var row := scene.instantiate() as Control
	row.set_meta("device_id", device_id)
	column.add_device_row(row)
	if row is DeviceRow:
		row.setup(device_id, device_id >= 0)
	if row.has_signal(&"move_requested"):
		row.connect(&"move_requested", _on_row_move_requested.bind(device_id, row))

#endregion

#region Move / Input

func _on_row_move_requested(direction: int, device_id: int, row: Control) -> void:
	_active_signal_row = row
	_on_move_requested(device_id, direction)
	_active_signal_row = null

func _on_move_requested(device_id: int, direction: int) -> void:
	if _pending or not _is_open or device_id < 0:
		return
	var current_seat := coop_manager.get_player_for_device(device_id)
	var max_seat: int = maxi(column_count, _columns.size()) - 1
	var new_seat := clampi(current_seat + direction, 0, max_seat)
	if new_seat == current_seat:
		return
	coop_manager.bind_device(device_id, new_seat)

func _input(event: InputEvent) -> void:
	if not _is_open or not visible:
		return

	_sync_router_actions()
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if input_router.interpret(event):
			_mark_input_handled()
		return

	if event.is_action_pressed(action_cancel):
		_mark_input_handled()
		_on_cancel()

func _on_accept_intent(device_id: int) -> void:
	if _pending or not _is_open:
		return
	if coop_manager.get_player_for_device(device_id) != LocalCoopManagerCode.PRIMARY_SLOT:
		return
	_on_submit()

func _on_cancel_intent(_device_id: int) -> void:
	_on_cancel()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel()

func _sync_router_actions() -> void:
	input_router.action_left = action_left
	input_router.action_right = action_right
	input_router.action_accept = action_accept
	input_router.action_cancel = action_cancel

func _mark_input_handled() -> void:
	if is_inside_tree() and get_viewport():
		get_viewport().set_input_as_handled()

#endregion

#region Coop Subscriptions

func _subscribe_coop() -> void:
	_unsubscribe_coop()
	if not is_instance_valid(coop_manager):
		return
	coop_manager.device_bound.connect(_on_device_changed)
	coop_manager.device_unbound.connect(_on_device_changed)
	coop_manager.slot_activated.connect(_on_slot_changed)
	coop_manager.slot_deactivated.connect(_on_slot_changed)

func _unsubscribe_coop() -> void:
	if not is_instance_valid(coop_manager):
		return
	if coop_manager.device_bound.is_connected(_on_device_changed):
		coop_manager.device_bound.disconnect(_on_device_changed)
	if coop_manager.device_unbound.is_connected(_on_device_changed):
		coop_manager.device_unbound.disconnect(_on_device_changed)
	if coop_manager.slot_activated.is_connected(_on_slot_changed):
		coop_manager.slot_activated.disconnect(_on_slot_changed)
	if coop_manager.slot_deactivated.is_connected(_on_slot_changed):
		coop_manager.slot_deactivated.disconnect(_on_slot_changed)

func _on_device_changed(_device_id: int, _slot: int) -> void:
	_render()

func _on_slot_changed(_slot: int) -> void:
	_render()

#endregion

#region Submit / Cancel

func _on_submit() -> void:
	if _pending or not _is_open:
		return
	for column in _columns:
		column.clear_rejection()
	_pending = true
	if submit_button:
		submit_button.disabled = true
	submitted.emit()

func _on_cancel() -> void:
	if not _is_open:
		return
	_unsubscribe_coop()
	_snapshot.restore(coop_manager)
	close()
	cancelled.emit()

#endregion
