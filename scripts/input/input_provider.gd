class_name InputProvider
extends RefCounted

## Thin wrapper around Godot's Input singleton for testability.
##
## LocalCoopManager depends on this instead of calling Input directly,
## so tests can inject a double via GUT's [code]double(InputProvider)[/code]
## and stub [method get_connected_joypads] to simulate gamepads already
## connected at startup.

## Returns the device IDs of currently connected joypads.
## Mirrors [method @GlobalScope.Input.get_connected_joypads].
func get_connected_joypads() -> Array[int]:
	return Input.get_connected_joypads()