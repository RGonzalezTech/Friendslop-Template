class_name InputProvider
extends RefCounted

## Thin wrapper around Godot's Input singleton for testability.
##
## LocalCoopManager depends on this instead of calling Input directly,
## so tests can inject a double via GUT's [code]double(InputProvider)[/code]
## and stub both [method get_connected_joypads] and the
## [signal joy_connection_changed] signal.

## Mirrors [signal @GlobalScope.Input.joy_connection_changed].
## Connect → auto-bind to slot 0. Disconnect → unbind.
signal joy_connection_changed(device_id: int, connected: bool)

func _init() -> void:
	# Relay the engine hotplug signal so tests can simulate it via emit()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

## Returns the device IDs of currently connected joypads.
## Mirrors [method @GlobalScope.Input.get_connected_joypads].
func get_connected_joypads() -> Array[int]:
	return Input.get_connected_joypads()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	joy_connection_changed.emit(device_id, connected)