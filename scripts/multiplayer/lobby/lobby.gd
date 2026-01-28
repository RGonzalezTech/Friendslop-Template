class_name Lobby
extends Node

## Data structure representing a multiplayer lobby's state.
## This node is automatically created by [LobbyManager] and synchronized via [MultiplayerSynchronizer].

enum State {
	NOT_CONNECTED, ## Default state before joining any session
	SERVER_LOADING, ## Host is setting up session or switching maps
	LOBBY, ## Players are joining and selecting options
	IN_GAME, ## Gameplay is active
	POST_GAME ## Game has ended, viewing results
}

## When the state of the lobby changes.
signal state_changed
## When the active map of the lobby changes.
signal map_changed

## The current state of the lobby. Triggers [state_changed].
@export var state: State = State.NOT_CONNECTED:
	set(value):
		if state == value: return
		state = value
		state_changed.emit()

@export var max_players: int = 4
@export var host_id: int = 1

## The current active map path. Triggers [map_changed].
## The [SceneManager] subscribes to this property to transition
## to the active map when it changes.
@export var active_map_path: String = "":
	set(value):
		if active_map_path == value: return
		active_map_path = value
		map_changed.emit()

var _synchronizer: MultiplayerSynchronizer

func _init() -> void:
	_setup_synchronizer()

## Programmatically creates a MultiplayerSynchronizer.
func _setup_synchronizer() -> void:
	_synchronizer = MultiplayerSynchronizer.new()
	_synchronizer.name = "MultiplayerSynchronizer"
	
	var config := SceneReplicationConfig.new()
	
	# Properties that should be synced from the server to others
	config.add_property(NodePath(":active_map_path"))
	config.add_property(NodePath(":state"))
	config.add_property(NodePath(":max_players"))
	config.add_property(NodePath(":host_id"))
	
	_synchronizer.replication_config = config
	add_child(_synchronizer)
