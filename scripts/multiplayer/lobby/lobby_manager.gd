class_name LobbyManagerCode
extends Node

## Manages the multiplayer lobby session life-cycle.
## Handles player connections, information syncing, and game transitions.
## 
## Example:
## [code]
## LobbyManager.initialize_lobby_as_host()
## LobbyManager.toggle_ready()
## LobbyManager.update_player_name("My Name")
## LobbyManager.reset_lobby()
## [/code]

## The name of the node that contains all [LobbyPlayer] nodes.
const LOBBY_PLAYERS_CONTAINER_NAME: String = "LobbyPlayers"

## Emitted when a player joins the lobby.
signal player_joined(peer_id: int)

## Emitted when a player leaves the lobby.
signal player_left(peer_id: int)

var current_lobby: Lobby
var _lobby_player_spawner: MultiplayerSpawner
var _lobby_players_container: Node
var disconnection_reason: String = ""

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
	
	reset_lobby()

func _setup_lobby_node() -> void:
	current_lobby = Lobby.new()
	current_lobby.name = "CurrentLobby"
	current_lobby.map_changed.connect(_on_map_changed)
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
	
func _spawn_player(data: int) -> Node:
	var new_player: LobbyPlayer = LobbyPlayer.new()
	new_player.peer_id = data
	new_player.player_name = "Player %d" % data
	return new_player

#endregion

#region Lobby Management API

## Cleans up the current session data.
func reset_lobby() -> void:
	for child in _lobby_players_container.get_children():
		child.queue_free()
	
	current_lobby.host_id = 1
	current_lobby.active_map_path = ""
	current_lobby.state = Lobby.State.NOT_CONNECTED

## Initializes the lobby session for the host.
func initialize_lobby_as_host() -> void:
	if not multiplayer.is_server():
		return

	reset_lobby()

	current_lobby.state = Lobby.State.SERVER_LOADING
	current_lobby.active_map_path = scene_manager.LOBBY_MENU
	current_lobby.host_id = multiplayer.get_unique_id()
	_add_player(current_lobby.host_id)

func _add_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	_lobby_player_spawner.spawn(peer_id)

#endregion

#region Player API

## Returns the player node for a given peer ID.
func get_player(peer_id: int) -> LobbyPlayer:
	return _lobby_players_container.get_node_or_null(str(peer_id)) as LobbyPlayer

## Returns the local player node.
func get_local_player() -> LobbyPlayer:
	return get_player(multiplayer.get_unique_id())

## Returns an array of all active lobby player nodes.
func get_all_players() -> Array[LobbyPlayer]:
	var list: Array[LobbyPlayer] = []
	for child in _lobby_players_container.get_children():
		if child is LobbyPlayer:
			list.append(child)
	return list

## Toggles the ready state of the local player.
func toggle_ready() -> void:
	var player_node = get_local_player()
	if player_node:
		player_node.is_ready = !player_node.is_ready

## Requests a name update. Server will validate and sync via RPC.
func update_player_name(new_name: String) -> void:
	var player_node = get_local_player()
	if player_node:
		player_node.player_name = new_name

#endregion

#region Networking Signals

func _on_connection_established() -> void:
	if multiplayer.is_server():
		initialize_lobby_as_host()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_add_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player_node = get_player(peer_id)
		if player_node:
			player_node.queue_free()

func _on_connection_shutdown(reason: String) -> void:
	reset_lobby()
	disconnection_reason = reason
	scene_manager.go_to_main_menu()

func _on_scene_load_failed(reason: String) -> void:
	disconnection_reason = reason
	scene_manager.go_to_main_menu()

func _on_map_changed() -> void:
	scene_manager.start_transition_to(current_lobby.active_map_path)

#endregion

#region Player Signals

func _on_player_added(node: Node) -> void:
	var player_node = node as LobbyPlayer
	if not player_node:
		return
		
	player_joined.emit(player_node.peer_id)

func _on_player_removed(node: Node) -> void:
	var player_node = node as LobbyPlayer
	if not player_node:
		return
		
	player_left.emit(player_node.peer_id)

#endregion
