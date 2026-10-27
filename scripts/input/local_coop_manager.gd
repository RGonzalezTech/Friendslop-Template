class_name LocalCoopManagerCode
extends Node

## Autoload that maps physical input devices to local player slots (seats).
##
## Owns the device→seat mapping. The network only needs "this peer has
## N players," not "gamepad 2 is seat 1" — this manager owns that mapping.
## Network handshake is triggered explicitly by the UI via [method LobbyManager.add_local_player].[br][br]
##
## [b]Example:[/b]
## [codeblock]
## LocalCoopManager.bind_device(0, 1)       # gamepad 0 → seat 1
## LocalCoopManager.unbind_device(0)        # release gamepad 0
## var seat := LocalCoopManager.get_player_for_device(0)
## if LocalCoopManager.is_coop:
##     show_split_screen()
## [/codeblock]

## The int that represents mouse and keyboard. Permanently bound to slot 0.
const MKB: int = -1

## The slot that MKB permanently occupies. Always active, never empty.
const PRIMARY_SLOT: int = 0

## Sentinel meaning "this device is not bound to any slot".
const NO_SLOT: int = -1

## Emitted when a device is bound to a slot.
signal device_bound(device_id: int, slot: int)

## Emitted when a device is unbound from a slot (explicit unbind or disconnect).
signal device_unbound(device_id: int, slot: int)

## Emitted when a slot transitions from empty to having at least one device.
## Consumed by the UI for seat-mapping feedback.
signal slot_activated(slot: int)

## Emitted when a slot transitions to empty (and is not the primary slot).
## Consumed by the UI for seat-mapping feedback.
signal slot_deactivated(slot: int)

## device_id → slot
var _device_to_slot: Dictionary = {}

## slot → Array[device_id]
var _slot_to_devices: Dictionary = {}


#region Lifecycle

func _ready() -> void:
	# MKB is permanently slot 0 — always active, never leaves.
	_bind_internal(MKB, PRIMARY_SLOT)

	# Gamepad hotplug: connect → auto-bind to slot 0, disconnect → unbind.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


#endregion


#region Public API — Mapping

## Binds [param device_id] to [param slot].
## [param device_id] of [constant MKB] is a no-op.
## If the device is already bound to another slot, it is auto-unbound first.
func bind_device(device_id: int, slot: int) -> void:
	if device_id == MKB:
		return

	var old_slot: int = _device_to_slot.get(device_id, NO_SLOT)
	if old_slot == slot:
		# Already on the requested slot — nothing to do.
		return
	else:
		# Leave the previous slot first.
		# Handles signals and cleanup.
		unbind_device(device_id)

	# Binds the device, then emits slot_activated / slot_deactivated as slots fill or empty.
	var new_slot_was_empty := not _slot_has_devices(slot)
	_bind_internal(device_id, slot)

	if new_slot_was_empty:
		slot_activated.emit(slot)

	device_bound.emit(device_id, slot)


## Unbinds [param device_id] from its current slot.
## [param device_id] of [constant MKB] is a no-op.
func unbind_device(device_id: int) -> void:
	if device_id == MKB:
		return

	if not _device_to_slot.has(device_id):
		return

	var old_slot: int = _device_to_slot[device_id]
	_unbind_internal(device_id)

	device_unbound.emit(device_id, old_slot)

	# If the slot is now empty (and not primary), emit deactivated.
	if _should_deactivate_slot(old_slot):
		slot_deactivated.emit(old_slot)

#endregion


#region Public API — Queries

## Returns the slot that [param device_id] is bound to.
## Unbound devices default to slot 0 (primary).
func get_player_for_device(device_id: int) -> int:
	return _device_to_slot.get(device_id, PRIMARY_SLOT)


## Returns all device IDs bound to [param slot].
func get_devices_for_player(slot: int) -> Array[int]:
	var devices: Array = _slot_to_devices.get(slot, [])
	var typed: Array[int] = []
	for d in devices:
		typed.append(d)
	return typed


## Number of distinct slots that have at least one bound device.
func get_active_players() -> int:
	return _slot_to_devices.size()


## True when more than one slot is active (split-screen / local co-op).
func get_is_coop() -> bool:
	return get_active_players() > 1


## Returns the list of currently active slot indices.
## Sparse slots are valid — e.g. [[0, 3]].
func get_active_slots() -> Array[int]:
	var slots: Array = _slot_to_devices.keys()
	var typed: Array[int] = []
	for s in slots:
		typed.append(s)
	return typed


## True when slot 0 has more than one device (MKB + at least one gamepad).
## Used to gate the "Add Split Screen" button:
##   LocalCoopManager.has_available_gamepad() and Lobby.has_room()
func has_available_gamepad() -> bool:
	var devices: Array = _slot_to_devices.get(PRIMARY_SLOT, [])
	return devices.size() > 1

#endregion


#region Internal — Dictionary Helpers

## Binds a device to a slot without triggering RPCs or signals.
##
## Keeps both lookup dictionaries in sync (see [member _device_to_slot] and
## [member _slot_to_devices]). Callers must unbind first if the device is already
## bound, otherwise it would be listed under two slots.
func _bind_internal(device_id: int, slot: int) -> void:
	_device_to_slot[device_id] = slot
	_add_device_to_slot_list(device_id, slot)


## Unbinds a device without triggering RPCs or signals.
##
## Keeps both lookup dictionaries in sync. Does nothing if the device is unbound.
## A slot left with no devices is removed entirely, so [method get_active_players]
## (which counts the keys of [member _slot_to_devices]) stays accurate.
func _unbind_internal(device_id: int) -> void:
	var slot: int = _device_to_slot.get(device_id, NO_SLOT)
	if slot == NO_SLOT:
		return

	_device_to_slot.erase(device_id)
	_remove_device_from_slot_list(device_id, slot)


## Appends [param device_id] to [param slot]'s device list, creating the list
## the first time the slot is used.
func _add_device_to_slot_list(device_id: int, slot: int) -> void:
	# If slot is empty, create a new array for it
	if not _slot_to_devices.has(slot):
		_slot_to_devices[slot] = []
		
	# Add the device to the slot
	_slot_to_devices[slot].append(device_id)


## Removes [param device_id] from [param slot]'s device list, and deletes the
## slot's entry if that leaves it empty.
func _remove_device_from_slot_list(device_id: int, slot: int) -> void:
	if not _slot_to_devices.has(slot):
		return

	_slot_to_devices[slot].erase(device_id)

	# If slot is now empty, remove it from the dictionary
	if _slot_to_devices[slot].is_empty():
		_slot_to_devices.erase(slot)


## True if [param slot] has at least one bound device.
func _slot_has_devices(slot: int) -> bool:
	return _slot_to_devices.has(slot) and not _slot_to_devices[slot].is_empty()


## True if a slot should be deactivated (it has emptied and is not the primary slot).
func _should_deactivate_slot(slot: int) -> bool:
	return slot != PRIMARY_SLOT and not _slot_has_devices(slot)

#endregion


#region Internal — Hotplug

## Reacts to gamepad connect / disconnect.
## Connect → auto-bind to slot 0. Disconnect → unbind.
func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		bind_device(device_id, PRIMARY_SLOT)
	else:
		unbind_device(device_id)

#endregion
