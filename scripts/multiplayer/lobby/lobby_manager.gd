class_name LobbyManagerCode
extends Node

## Manages the multiplayer lobby session life-cycle.
## Handles player connections, information syncing, and game transitions.
## 
## Example:
## [code]
## LobbyManager.initialize_lobby_as_host()
## LobbyManager.update_player_name("My Name")
## LobbyManager.reset_lobby()
## [/code]

## The name of the node that contains all [LobbyPlayer] nodes.
const LOBBY_PLAYERS_CONTAINER_NAME: String = "LobbyPlayers"

## Shorthand for [method LobbyPlayer.UNSET_DEVICE_IDX]
const UNSET_DEVICE_IDX: int = LobbyPlayer.UNSET_DEVICE_IDX

## Emitted when a player joins the lobby.
signal player_joined(peer_id: int, device_idx: int)

## Emitted when a player leaves the lobby.
signal player_left(peer_id: int, device_idx: int)

## Emitted when a player's status changes.
signal player_status_update(peer_id: int, device_idx: int, status: LobbyPlayer.Status)

var current_lobby: Lobby
var _lobby_player_spawner: MultiplayerSpawner
var _lobby_players_container: Node
var disconnection_reason: String = ""

## Dictionary of peer_id -> device_idx -> LobbyPlayer
var _players_by_peer_and_device: Dictionary[int, Dictionary] = {}

## Refrence to the scene manager. Can be overridden for testing.
var scene_manager: SceneManagerCode = SceneManager

#region init

func _init() -> void:
	_setup_lobby_node()
	_setup_spawner()

func _ready() -> void:
	scene_manager = SceneManager

	# Listen to network events
	PeerManager.connection_established.connect(_on_connection_established)
	PeerManager.connection_shutdown.connect(_on_connection_shutdown)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	scene_manager.load_failed.connect(_on_scene_load_failed)
	scene_manager.is_loading_update.connect(_on_scene_loading_update)
	
	reset_lobby()

func _setup_lobby_node() -> void:
	current_lobby = Lobby.new()
	current_lobby.name = "CurrentLobby"
	current_lobby.scene_changed.connect(_on_scene_changed)
	add_child(current_lobby)

func _setup_spawner() -> void:
	_lobby_players_container = Node.new()
	_lobby_players_container.name = LOBBY_PLAYERS_CONTAINER_NAME
	# Automatically handle registration/unregistration via node signals
	_lobby_players_container.child_entered_tree.connect(_on_player_added)
	_lobby_players_container.child_exiting_tree.connect(_on_player_removed)
	add_child(_lobby_players_container)
	
	## Path to the container node that will hold the [LobbyPlayer] nodes.
	var spawn_path: String = "../%s" % [LOBBY_PLAYERS_CONTAINER_NAME]

	## Spawner that will handle the synchronization of [LobbyPlayer] nodes.
	_lobby_player_spawner = MultiplayerSpawner.new()
	_lobby_player_spawner.name = "LobbyPlayerSpawner"
	_lobby_player_spawner.spawn_path = NodePath(spawn_path)
	_lobby_player_spawner.spawn_function = _spawn_player
	add_child(_lobby_player_spawner)
	
func _spawn_player(data: Array) -> Node:
	var peer_id: int = data[0]
	var device_idx: int = data[1]
	
	var new_player: LobbyPlayer = LobbyPlayer.new()
	new_player.peer_id = peer_id
	new_player.device_idx = device_idx
	new_player.player_name = "Player %d-%d" % [peer_id, device_idx]
	new_player.status_changed.connect(_on_player_status_changed.bind(new_player.peer_id, new_player.device_idx))
	return new_player

#endregion

#region Lobby Management API

## Cleans up the current session data.
func reset_lobby() -> void:
	for child in _lobby_players_container.get_children():
		child.queue_free()
	_players_by_peer_and_device.clear()
	
	current_lobby.host_id = 1
	current_lobby.active_scene_path = ""
	current_lobby.state = Lobby.State.NOT_CONNECTED

## Initializes the lobby session for the host.
func initialize_lobby_as_host() -> void:
	if not multiplayer.is_server():
		return

	reset_lobby()

	current_lobby.state = Lobby.State.SERVER_LOADING
	current_lobby.active_scene_path = scene_manager.LOBBY_MENU
	current_lobby.host_id = multiplayer.get_unique_id()
	_add_player(current_lobby.host_id)

func _add_player(peer_id: int, device_idx: int = UNSET_DEVICE_IDX) -> void:
	if not multiplayer.is_server():
		return
	
	_lobby_player_spawner.spawn([peer_id, device_idx])

#endregion

#region Player API

## Returns the player node for a given peer ID and device ID.
func get_player(peer_id: int, device_idx: int = UNSET_DEVICE_IDX) -> LobbyPlayer:
	var players_for_peer: Dictionary = _players_by_peer_and_device.get(peer_id, {})
	return players_for_peer.get(device_idx)

## Returns true if the player is ready for gameplay.
## This is determined by the player's status.
func is_player_ready_for_gameplay(peer_id: int, device_idx: int = UNSET_DEVICE_IDX) -> bool:
	var this_player = get_player(peer_id, device_idx)
	if not this_player:
		return false

	const SYNCED = LobbyPlayer.Status.SYNCED
	const IN_GAME = LobbyPlayer.Status.IN_GAME
	match this_player.status:
		SYNCED, IN_GAME:
			# Either status is fine for gameplay.
			return true
		_:
			# Any other status is not ready for gameplay.
			return false

## Returns the local player node.
func get_local_player(device_idx: int = UNSET_DEVICE_IDX) -> LobbyPlayer:
	var has_peer = multiplayer.multiplayer_peer
	if not has_peer:
		return null
	
	var conn_status = has_peer.get_connection_status()
	if conn_status != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		return null

	return get_player(multiplayer.get_unique_id(), device_idx)

## Returns an array of all active lobby player nodes.
func get_all_players() -> Array[LobbyPlayer]:
	var list: Array[LobbyPlayer] = []
	for child in _lobby_players_container.get_children():
		if child is LobbyPlayer:
			list.append(child)
	return list

## Requests a name update. Server will validate and sync via RPC.
func update_player_name(new_name: String, device_idx: int = UNSET_DEVICE_IDX) -> void:
	var player_node = get_local_player(device_idx)
	if player_node:
		player_node.update_player_name.rpc_id(1, new_name)

## Requests a status update. Server will validate and sync via RPC.
func update_player_status(new_status: LobbyPlayer.Status, device_idx: int = UNSET_DEVICE_IDX) -> void:
	var player_node = get_local_player(device_idx)
	if player_node:
		player_node.set_status.rpc_id(1, new_status)

#endregion

#region Networking Signals

func _on_connection_established() -> void:
	if multiplayer.is_server():
		initialize_lobby_as_host()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_add_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Remove all players associated with this peer_id
	var players_for_peer = _players_by_peer_and_device.get(peer_id)
	if not players_for_peer:
		return
	
	for device_idx in players_for_peer.keys():
		var player_node = players_for_peer[device_idx]
		if player_node:
			player_node.queue_free()
	_players_by_peer_and_device.erase(peer_id)

func _on_connection_shutdown(reason: String) -> void:
	reset_lobby()
	disconnection_reason = reason
	scene_manager.go_to_main_menu()

func _on_scene_load_failed(reason: String) -> void:
	disconnection_reason = reason
	scene_manager.go_to_main_menu()

func _on_scene_changed() -> void:
	scene_manager.start_transition_to(current_lobby.active_scene_path)


# When the scene manager reports its loading status, we can update the local player's status.
func _on_scene_loading_update(is_loading: bool) -> void:
	const LOADING = LobbyPlayer.Status.SCENE_LOADING
	const SYNCED = LobbyPlayer.Status.SYNCED
	update_player_status(LOADING if is_loading else SYNCED)

#endregion

#region Player Signals

func _on_player_added(node: Node) -> void:
	var player_node := node as LobbyPlayer
	if not player_node:
		return
		
	var peer_dict: Dictionary = _players_by_peer_and_device.get_or_add(player_node.peer_id, {})
	peer_dict[player_node.device_idx] = player_node
	player_joined.emit(player_node.peer_id, player_node.device_idx)

func _on_player_removed(node: Node) -> void:
	var player_node := node as LobbyPlayer
	if not player_node:
		return
		
	var peer_dict: Dictionary = _players_by_peer_and_device.get(player_node.peer_id, {})
	if peer_dict.erase(player_node.device_idx):
		# If we actually removed something,
		if peer_dict.is_empty():
			# remove the peer entry if it has 0 devices.
			_players_by_peer_and_device.erase(player_node.peer_id)
	player_left.emit(player_node.peer_id, player_node.device_idx)

func _on_player_status_changed(status: LobbyPlayer.Status, peer_id: int, device_idx: int) -> void:
	player_status_update.emit(peer_id, device_idx, status)
#endregion
