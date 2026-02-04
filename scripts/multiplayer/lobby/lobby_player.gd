class_name LobbyPlayer
extends Node

## Represents an active player in the lobby session.
## This node is automatically spawned on all peers by [LobbyManager]'s MultiplayerSpawner.

## The status of the player in the lobby.
enum Status {
	CONNECTING, ## Initial state on joining
	SCENE_LOADING, ## Player is loading the game scene
	SYNCED, ## Finished handshake/syncing world state
	IN_GAME ## Active in the game world
}

## Emitted when any of the player's properties change.
signal info_changed

## Emitted when the player's status changes.
signal status_changed(status: Status)

## The peer ID of the player.
@export var peer_id: int = 0:
	set(value):
		peer_id = value
		name = str(peer_id)
		info_changed.emit()

## The name of the player.
@export var player_name: String = "Player":
	set(value):
		if player_name == value: return
		player_name = value
		info_changed.emit()

## The status of the player in the lobby.
@export var status: Status = Status.CONNECTING:
	set(value):
		if status == value: return
		status = value
		info_changed.emit()
		status_changed.emit(status)

var _server_sync: MultiplayerSynchronizer

func _init() -> void:
	_setup_synchronizers()

## Updates the name of the player.
## Expects remote sender == peer_id.
@rpc("any_peer", "call_local", "reliable")
func update_player_name(new_name: String) -> void:
	if not multiplayer.is_server():
		push_warning("Only server can change a player's name")
		return

	# A player can only update their own name
	if multiplayer.get_remote_sender_id() != peer_id:
		push_warning("Only the player can update their own name")
		return

	player_name = new_name

@rpc("any_peer", "call_local", "reliable")
func set_status(new_status: Status) -> void:
	if not multiplayer.is_server():
		push_warning("Only server can change a player's status")
		return

	# A player can only update their own status
	if multiplayer.get_remote_sender_id() != peer_id:
		push_warning("Only the player can update their own status")
		return

	status = new_status

## Programmatically creates MultiplayerSynchronizer.
## This allows the script to function without a pre-made scene.
func _setup_synchronizers() -> void:
	# Server-authoritative synchronizer (for status)
	_server_sync = MultiplayerSynchronizer.new()
	_server_sync.name = "ServerSynchronizer"
	
	var server_config := SceneReplicationConfig.new()
	server_config.add_property(NodePath(":status"))
	server_config.add_property(NodePath(":player_name"))
	
	_server_sync.replication_config = server_config
	add_child(_server_sync)
