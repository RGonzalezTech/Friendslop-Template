class_name SeatSnapshot
extends RefCounted

## Captures the device→seat map at modal open, for Cancel rollback.
##
## Reads from [LocalCoopManagerCode] via its public API; [method restore] re-
## applies bindings through the same API so the modal's reactive signal loop
## re-renders for free. Deliberately a dumb value object — no UI, no signals.

var _device_to_slot: Dictionary = {}  ## device_id -> slot

## Captures the current device→slot mapping from [param manager].
func capture(manager: LocalCoopManagerCode) -> void:
	_device_to_slot.clear()
	for slot in manager.get_active_slots():
		for device in manager.get_devices_for_player(slot):
			_device_to_slot[device] = slot

## Re-binds every captured device to its captured slot.
func restore(manager: LocalCoopManagerCode) -> void:
	for device in _device_to_slot:
		manager.bind_device(device, _device_to_slot[device])

## Records a single device (used for gamepads hotplugged after capture).
func add(device_id: int, slot: int) -> void:
	_device_to_slot[device_id] = slot

## The captured slot for [param device_id], or the primary slot (0) if unknown.
func get_seat(device_id: int) -> int:
	return _device_to_slot.get(device_id, LocalCoopManagerCode.PRIMARY_SLOT)

func is_empty() -> bool:
	return _device_to_slot.is_empty()
