class_name DeviceMappingModal
extends PopupPanel

## Composition root for the device-mapping UI.
##
## Owns the columns and delegates everything else to small single-purpose
## objects. The single source of truth is [LocalCoopManagerCode]; this modal is a
## pure projection of it — it subscribes to its signals and re-parents rows,
## never mutating the UI directly.
##
## Lives entirely in the local input layer: it edits LocalCoopManager live and
## emits [signal submitted] / [signal cancelled] so a caller (e.g. the lobby)
## can decide what to do next. It knows nothing about the network or LobbyManager.

## Emitted when the user confirms the mapping via Submit. Bindings are already
## live in LocalCoopManager; the caller decides how to commit them.
signal submitted

## Emitted when the user cancels. Bindings have already been restored from the
## snapshot; the caller just needs to close up.
signal cancelled

const PLAYER_COLUMN_SCENE: PackedScene = preload("res://scenes/ui/device_mapping/PlayerColumn.tscn")
const DEVICE_ROW_SCENE: PackedScene = preload("res://scenes/ui/device_mapping/DeviceRow.tscn")

@export var column_count: int = 4  ## Default; override via [method open_mapping].

@onready var seat_columns: HBoxContainer = %SeatColumns
@onready var submit_button: Button = %SubmitButton
@onready var cancel_button: Button = %CancelButton

## Dependency seam — defaults to the autoload, inject a double in tests.
var coop_manager: LocalCoopManagerCode = LocalCoopManager

## Visual set + input interpreter. Swappable / injectable.
var visual_factory: DeviceVisualFactory = DeviceVisualFactory.new()
var input_router: DeviceInputRouter = DeviceInputRouter.new()

var _columns: Array[PlayerColumn] = []
var _snapshot: SeatSnapshot = SeatSnapshot.new()
var _committed: bool = false

func _ready() -> void:
	exclusive = true
	submit_button.pressed.connect(_on_submit)
	cancel_button.pressed.connect(_on_cancel)
	popup_hide.connect(queue_free)
	input_router.move_intent.connect(_on_move_requested)

func _exit_tree() -> void:
	_unsubscribe_coop()

#region Public API

## Opens the modal: builds columns, snapshots bindings, and populates from
## [LocalCoopManagerCode]. Pass [param player_count] to override the column count
## (previews, tests, custom layouts); otherwise the [member column_count] export
## is used.
func open_mapping(player_count: int = -1) -> void:
	_committed = false
	if player_count > 0:
		column_count = player_count

	_snapshot.capture(coop_manager)

	_subscribe_coop()
	_build_columns()
	_populate_columns()

	popup_centered()

#endregion

#region Build / Populate

func _build_columns() -> void:
	for child in seat_columns.get_children():
		child.queue_free()
	_columns.clear()

	for seat in range(column_count):
		var column := PLAYER_COLUMN_SCENE.instantiate() as PlayerColumn
		seat_columns.add_child(column)
		column.setup(seat, seat == LocalCoopManagerCode.PRIMARY_SLOT)
		_columns.append(column)

func _populate_columns() -> void:
	for column in _columns:
		for device in coop_manager.get_devices_for_player(column.seat_index):
			_add_row_to_column(column, device)
		column.set_state(PlayerColumn.SlotState.ACTIVE if column.is_occupied() else PlayerColumn.SlotState.EMPTY)

func _add_row_to_column(column: PlayerColumn, device_id: int) -> void:
	var row := DEVICE_ROW_SCENE.instantiate() as DeviceRow
	column.add_device_row(row)  # enters the tree so @onready resolves before setup
	var visual := visual_factory.create(DeviceVisualFactory.type_for_device(device_id))
	row.setup(device_id, visual, device_id >= 0)  # MKB (< 0) is not movable
	row.move_requested.connect(_on_move_requested.bind(device_id))

#endregion

#region Move (single entry point for every move intent)

func _on_move_requested(device_id: int, direction: int) -> void:
	if _committed or device_id < 0:
		return
	var current_seat := coop_manager.get_player_for_device(device_id)
	var new_seat := clampi(current_seat + direction, 0, column_count - 1)
	if new_seat == current_seat:
		return
	coop_manager.bind_device(device_id, new_seat)

#endregion

#region Reactive projection (LocalCoopManager -> UI)

func _subscribe_coop() -> void:
	coop_manager.device_bound.connect(_on_device_bound)
	coop_manager.device_unbound.connect(_on_device_unbound)
	coop_manager.slot_activated.connect(_on_slot_activated)
	coop_manager.slot_deactivated.connect(_on_slot_deactivated)
	coop_manager.input_provider.joy_connection_changed.connect(_on_joy_connection_changed)

func _unsubscribe_coop() -> void:
	if not is_instance_valid(coop_manager):
		return
	if coop_manager.device_bound.is_connected(_on_device_bound):
		coop_manager.device_bound.disconnect(_on_device_bound)
	if coop_manager.device_unbound.is_connected(_on_device_unbound):
		coop_manager.device_unbound.disconnect(_on_device_unbound)
	if coop_manager.slot_activated.is_connected(_on_slot_activated):
		coop_manager.slot_activated.disconnect(_on_slot_activated)
	if coop_manager.slot_deactivated.is_connected(_on_slot_deactivated):
		coop_manager.slot_deactivated.disconnect(_on_slot_deactivated)
	if coop_manager.input_provider.joy_connection_changed.is_connected(_on_joy_connection_changed):
		coop_manager.input_provider.joy_connection_changed.disconnect(_on_joy_connection_changed)

func _on_device_bound(device_id: int, slot: int) -> void:
	if slot >= _columns.size():
		return
	var row := _find_row(device_id)
	if row == null:
		_add_row_to_column(_columns[slot], device_id)
	else:
		var parent := row.get_parent()
		if parent:
			parent.remove_child(row)
		_columns[slot].add_device_row(row)

func _on_device_unbound(device_id: int, slot: int) -> void:
	# A move also emits device_unbound (unbind) immediately before device_bound
	# (bind). Defer the removal so the follow-up device_bound can re-parent the
	# row first; the deferred check only frees the row if it was NOT re-parented
	# — i.e. a genuine disconnect.
	_remove_row_if_still_present.call_deferred(device_id, slot)

func _remove_row_if_still_present(device_id: int, slot: int) -> void:
	if slot >= _columns.size():
		return
	_columns[slot].remove_device_row(device_id)

func _on_slot_activated(slot: int) -> void:
	if slot < _columns.size():
		_columns[slot].set_state(PlayerColumn.SlotState.ACTIVE)

func _on_slot_deactivated(slot: int) -> void:
	if slot < _columns.size():
		_columns[slot].set_state(PlayerColumn.SlotState.EMPTY)

## Hotplug: rows are created/removed reactively by device_bound/device_unbound.
## We only extend the snapshot so Cancel can roll back a pad that arrived after
## open.
func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if _committed:
		return
	if connected:
		_snapshot.add(device_id, coop_manager.get_player_for_device(device_id))

func _find_row(device_id: int) -> DeviceRow:
	for column in _columns:
		var row := column.get_device_row(device_id)
		if row:
			return row
	return null

#endregion

#region Input

func _unhandled_input(event: InputEvent) -> void:
	if _committed:
		return
	input_router.interpret(event)

#endregion

#region Submit / Cancel

func _on_submit() -> void:
	_committed = true
	submit_button.disabled = true
	submitted.emit()
	hide()

func _on_cancel() -> void:
	if not _committed:
		_unsubscribe_coop()
		_snapshot.restore(coop_manager)
	cancelled.emit()
	hide()

#endregion
