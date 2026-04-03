class_name LobbyManagerCode
extends Node

## This autoload manages the multiplayer lobby session life-cycle.
## 
## Responds to player connections and monitors player states as they join, leave, and load scenes.[br][br]
## 
## [b]Example:[/b]
## [codeblock]
## LobbyManager.initialize_lobby_as_host()
## LobbyManager.update_player_name("My Name")
## LobbyManager.reset_lobby()
## [/codeblock]

## The name of the node that contains all [LobbyPlayer] nodes.
const LOBBY_PLAYERS_CONTAINER_NAME: String = "LobbyPlayers"

## Reference to the default local player id. See [method LobbyPlayer.DEFAULT_LOCAL_PLAYER_ID].
const DEFAULT_LOCAL_PLAYER_ID: int = LobbyPlayer.DEFAULT_LOCAL_PLAYER_ID

## Emitted when a player joins the lobby.
signal player_joined(peer_id: int, local_player_id: int)

## Emitted when a player leaves the lobby.
signal player_left(peer_id: int, local_player_id: int)

## Emitted when a player's status changes.
signal player_status_update(peer_id: int, local_player_id: int, status: LobbyPlayer.Status)

var current_lobby: Lobby
var _lobby_player_spawner: MultiplayerSpawner
var _lobby_players_container: Node
var disconnection_reason: String = ""

## Dictionary of peer_id -> local_player_id -> LobbyPlayer
var _players_by_peer_and_local_id: Dictionary[int, Dictionary] = {}

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
	var local_player_id: int = data[1]
	
	return create_player(peer_id, local_player_id)

#endregion

#region Lobby Management API

## Cleans up the current session data.
func reset_lobby() -> void:
	for child in _lobby_players_container.get_children():
		child.queue_free()
	_players_by_peer_and_local_id.clear()
	
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

func _add_player(peer_id: int, local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> void:
	if not multiplayer.is_server():
		return
	
	_lobby_player_spawner.spawn([peer_id, local_player_id])

#endregion

#region Player API

## Simply creates a [LobbyPlayer], unless [param local_player_id] is not the default value.
## If [param local_player_id] is not the default value, it will try to find the host player
## and set it as the parent of the new player.
func create_player(peer_id: int, local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> LobbyPlayer:
	var new_player = LobbyPlayer.new()
	new_player.peer_id = peer_id

	if local_player_id != DEFAULT_LOCAL_PLAYER_ID:
		# Trying to create a guest player.
		# Check if we have a "host"
		var host_player = get_player(peer_id)
		if not host_player:
			new_player.free()
			return null
		
		new_player._parent_lobby_player = host_player
		new_player.local_player_id = local_player_id
	
	return new_player

## Returns the player node for a given peer ID and device ID.
func get_player(peer_id: int, local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> LobbyPlayer:
	var players_for_peer := get_players(peer_id)
	return players_for_peer.get(local_player_id)

## Returns a Dictionary of local_player_id -> LobbyPlayer for a given peer ID.
func get_players(peer_id: int) -> Dictionary:
	return _players_by_peer_and_local_id.get(peer_id, {})

## Returns true if the player is ready for gameplay.
## This is determined by the player's status.
func is_player_ready_for_gameplay(peer_id: int, local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> bool:
	var this_player = get_player(peer_id, local_player_id)
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
func get_local_player(local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> LobbyPlayer:
	var has_peer = multiplayer.multiplayer_peer
	if not has_peer:
		return null
	
	var conn_status = has_peer.get_connection_status()
	if conn_status != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		return null

	return get_player(multiplayer.get_unique_id(), local_player_id)

## Returns a Dictionary of local_player_id -> LobbyPlayer for the local peer.
func get_local_players() -> Dictionary:
	var has_peer = multiplayer.multiplayer_peer
	if not has_peer:
		return {}
	
	var conn_status = has_peer.get_connection_status()
	if conn_status != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		return {}

	return get_players(multiplayer.get_unique_id())

## Returns an array of all active lobby player nodes.
func get_all_players() -> Array[LobbyPlayer]:
	var list: Array[LobbyPlayer] = []
	for child in _lobby_players_container.get_children():
		if child is LobbyPlayer:
			list.append(child)
	return list

## Returns an array of all active lobby player peer IDs.
func get_all_player_peer_ids() -> Array[int]:
	return _players_by_peer_and_local_id.keys()

## Requests a name update. Server will validate and sync via RPC.
func update_player_name(new_name: String) -> void:
	var player_node = get_local_player(DEFAULT_LOCAL_PLAYER_ID)
	if player_node:
		player_node.update_player_name.rpc_id(1, new_name)

## Requests a status update. Server will validate and sync via RPC.
func update_player_status(new_status: LobbyPlayer.Status, local_player_id: int = DEFAULT_LOCAL_PLAYER_ID) -> void:
	var player_node = get_local_player(local_player_id)
	if player_node:
		player_node.set_status.rpc_id(1, new_status)

## For each [LobbyPlayer] spawned for our peer, we request that it is
## updated to the given status.
func update_all_local_player_status(new_status: LobbyPlayer.Status) -> void:
	var local_players = get_local_players()
	for local_player_id in local_players.keys():
		update_player_status(new_status, local_player_id)

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
	var players_for_peer = get_players(peer_id)

	for local_player_id in players_for_peer.keys():
		var player_node = players_for_peer[local_player_id]
		if player_node:
			player_node.queue_free()
	_players_by_peer_and_local_id.erase(peer_id)

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
		
	player_node.status_changed.connect(_on_player_status_changed.bind(player_node.peer_id, player_node.local_player_id))
	var peer_dict: Dictionary = _players_by_peer_and_local_id.get_or_add(player_node.peer_id, {})
	peer_dict[player_node.local_player_id] = player_node
	player_joined.emit(player_node.peer_id, player_node.local_player_id)

func _on_player_removed(node: Node) -> void:
	var player_node := node as LobbyPlayer
	if not player_node:
		return
		
	var peer_dict: Dictionary = _players_by_peer_and_local_id.get(player_node.peer_id, {})
	if peer_dict.erase(player_node.local_player_id):
		# If we actually removed something,
		if peer_dict.is_empty():
			# remove the peer entry if it has 0 devices.
			_players_by_peer_and_local_id.erase(player_node.peer_id)
	player_left.emit(player_node.peer_id, player_node.local_player_id)

func _on_player_status_changed(status: LobbyPlayer.Status, peer_id: int, local_player_id: int) -> void:
	player_status_update.emit(peer_id, local_player_id, status)
#endregion
