class_name LobbyPlayer
extends Node

## Represents an active player in the lobby session.
## This node is automatically spawned on all peers by [LobbyManager]'s MultiplayerSpawner.

enum Status {
	CONNECTING, ## Initial state on joining
	SYNCED, ## Finished handshake/syncing world state
	LOADING, ## Specifically loading a map scene
	IN_GAME ## Active in the game world
}

## Emitted when any of the player's properties change.
signal info_changed

## The peer ID of the player. 
@export var peer_id: int = 0:
	set(value):
		peer_id = value
		name = str(peer_id)
		_apply_multiplayer_authority(peer_id)
		info_changed.emit()

## The name of the player. 
@export var player_name: String = "Player":
	set(value):
		if player_name == value: return
		player_name = value
		info_changed.emit()

@export var is_ready: bool = false:
	set(value):
		if is_ready == value: return
		is_ready = value
		info_changed.emit()

@export var status: Status = Status.CONNECTING:
	set(value):
		if status == value: return
		status = value
		info_changed.emit()

var _player_sync: MultiplayerSynchronizer
var _server_sync: MultiplayerSynchronizer

func _init() -> void:
	_setup_synchronizers()

## Programmatically creates MultiplayerSynchronizers.
## This allows the script to function without a pre-made scene.
## 
## ARCHITECTURE NOTE: We use two synchronizers to enforce authority:
## 1. PlayerSynchronizer: Owned by the Peer ID. Only they can change their name/ready status.
## 2. ServerSynchronizer: Owned by the Server (ID 1). Only the server can change player status.
func _setup_synchronizers() -> void:
	# Player-authoritative synchronizer (for name, readiness, etc.)
	_player_sync = MultiplayerSynchronizer.new()
	_player_sync.name = "PlayerSynchronizer"
	_apply_multiplayer_authority(peer_id)
	
	var player_config := SceneReplicationConfig.new()
	player_config.add_property(NodePath(":player_name"))
	player_config.add_property(NodePath(":is_ready"))
	
	_player_sync.replication_config = player_config
	add_child(_player_sync)

	# Server-authoritative synchronizer (for status)
	_server_sync = MultiplayerSynchronizer.new()
	_server_sync.name = "ServerSynchronizer"
	_server_sync.set_multiplayer_authority(1)
	
	var server_config := SceneReplicationConfig.new()
	server_config.add_property(NodePath(":status"))
	
	_server_sync.replication_config = server_config
	add_child(_server_sync)

func _apply_multiplayer_authority(id: int) -> void:
	set_multiplayer_authority(id, false) # recursive=false to protect ServerSynchronizer
	if _player_sync:
		_player_sync.set_multiplayer_authority(id)
