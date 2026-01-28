extends RefCounted
class_name BaseNetworkProvider

## Abstract base class for network providers (ENet, Steam, etc).
## Handles high-level connection initialization and teardown.

## Emitted when the provider successfully creates a multiplayer peer.
# @warning_ignore("unused_signal")
signal connection_created(peer: MultiplayerPeer)

## Emitted when the provider fails to initialize the connection.
# @warning_ignore("unused_signal")
signal connection_failed(reason: String)


## Called when the provider is initialized with its specific settings.
func _init() -> void:
	pass

## Starts hosting a game asynchronously.
## Should eventually emit [signal connection_created] or [signal connection_failed].
func host_game() -> void:
	assert(false, "host_game() must be implemented by a subclass.")

## Joins a game asynchronously.
## Should eventually emit [signal connection_created] or [signal connection_failed].
func join_game() -> void:
	assert(false, "join_game() must be implemented by a subclass.")

## Returns the name of the provider class for debugging.
func get_class_name() -> String:
	assert(false, "get_class_name() must be implemented by a subclass.")
	return ""

## Shuts down the provider and cleans up resources.
## Override this to provide specific cleanup logic (e.g., closing Steam lobbies).
func shutdown() -> void:
	assert(false, "shutdown() must be implemented by a subclass.")
