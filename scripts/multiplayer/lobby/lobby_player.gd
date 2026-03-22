class_name LobbyPlayer
extends Node

## Represents an active player in the lobby session.
## This node is automatically spawned on all peers by [LobbyManagerCode]'s MultiplayerSpawner.

## Local players start at index 0. This is the default value for [member local_player_id].
const DEFAULT_LOCAL_PLAYER_ID: int = 0

## The status of the player in the lobby.
enum Status {
	CONNECTING, ## Initial state on joining
	SCENE_LOADING, ## Player is loading the game scene
	SYNCED, ## Finished handshake/syncing world state
	IN_GAME ## Active in the game world
}

## Emitted when any of the player's properties change.
signal info_changed

## Emitted when the player's [member status] changes.
signal status_changed(status: Status)

## The peer ID of the player.
@export var peer_id: int = 0:
	set(value):
		if peer_id == value:
			# No change, do nothing
			return
		# Else: update node name
		peer_id = value
		_set_name()
		info_changed.emit()

## The local device index that controls this player.
@export var local_player_id: int = DEFAULT_LOCAL_PLAYER_ID:
	set(value):
		if local_player_id == value:
			# No change, do nothing
			return
		# Else: update node name
		local_player_id = value
		_set_name()
		info_changed.emit()

## The name of the player.
@export var player_name: String = "Player":
	set(value):
		if player_name == value:
			return
		player_name = value
		info_changed.emit()

## The status of the player in the lobby.
@export var status: Status = Status.CONNECTING:
	set(value):
		if status == value:
			return
		status = value
		info_changed.emit()
		status_changed.emit(status)

var _server_sync: MultiplayerSynchronizer

func _init() -> void:
	_setup_synchronizers()

# Sets the node name (for MultiplayerSpawner/Synchronizer)
func _set_name() -> void:
	name = str(peer_id) + "_" + str(local_player_id)

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
