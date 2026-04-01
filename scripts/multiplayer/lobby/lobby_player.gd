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
		peer_id = value
		_apply_ids()

## Optional, only necessary when [member local_player_id] != [member DEFAULT_LOCAL_PLAYER_ID].
## This is the player that spawned this player.
var _parent_lobby_player: LobbyPlayer:
	set(new):
		if _parent_lobby_player == new:
			return
		
		if _parent_lobby_player and _parent_lobby_player.info_changed.is_connected(_on_parent_info_changed):
			_parent_lobby_player.info_changed.disconnect(_on_parent_info_changed)
			
		_parent_lobby_player = new
		
		if _parent_lobby_player:
			_parent_lobby_player.info_changed.connect(_on_parent_info_changed)
			
		info_changed.emit()

## The local device index that controls this player.
@export var local_player_id: int = DEFAULT_LOCAL_PLAYER_ID:
	set(value):
		if local_player_id == value:
			# No change, do nothing
			return
		local_player_id = value
		_apply_ids()

## The name of the player.
@export var player_name: String = "Peer 0":
	get = _get_player_name,
	set = _set_player_name

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

func _on_parent_info_changed() -> void:
	info_changed.emit()

# Apply the IDs to the node name and emit info_changed
func _apply_ids() -> void:
	_set_node_name()
	info_changed.emit()

# Sets the node name (for MultiplayerSpawner/Synchronizer)
func _set_node_name() -> void:
	name = str(peer_id) + "_" + str(local_player_id)

func _set_player_name(value: String) -> void:
	if local_player_id != DEFAULT_LOCAL_PLAYER_ID:
		push_warning("Trying to set player_name on guest player. Only the host player can accept updates to player_name.")
		return

	if player_name == value:
		# No change, do nothing
		return

	player_name = value
	info_changed.emit()

func _get_player_name() -> String:
	if local_player_id == DEFAULT_LOCAL_PLAYER_ID:
		return player_name
	else:
		_assert_parent_player()
		var parent_name = _parent_lobby_player.player_name
		return "%s (%d)" % [parent_name, local_player_id]

# Assert that we have a valid parent player
func _assert_parent_player() -> void:
	# This is a guest player now.
	# Make sure they they have a parent.
	assert(_parent_lobby_player, "Guest player must have a parent")
	assert(_parent_lobby_player.peer_id == peer_id, "Guest player's parent must have the same peer_id")
	assert(_parent_lobby_player.local_player_id == DEFAULT_LOCAL_PLAYER_ID, "Guest player's parent must be the host player")

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
