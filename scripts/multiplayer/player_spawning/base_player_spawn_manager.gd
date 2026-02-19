class_name BasePlayerSpawnManager
extends Node

## Abstract base class for managing player spawning and despawning lifecycle.
## Subclasses must implement _get_spawn_params() to define *where* and *how* players spawn.

## The level's root node responsible for announcing when players are synced
@export var network_level_root: NetworkLevelRoot
## The level's spawning node for players
@export var handshake_spawner: HandshakeSpawner
## The label used to identify players in the handshake spawner
@export var player_spawner_label: String = "player"

## Dictionary mapping peer_id -> SpawnRequest (or just metadata if needed)
var _spawned_players: Dictionary[int, SpawnRequest] = {}

func _enter_tree() -> void:
	assert(network_level_root, "BasePlayerSpawnManager must have a reference to the NetworkLevelRoot")
	network_level_root.player_ready_for_gameplay.connect(_on_player_ready_for_gameplay)
	
	LobbyManager.player_left.connect(_on_player_left)

func _ready() -> void:
	assert(handshake_spawner, "BasePlayerSpawnManager must have a reference to the HandshakeSpawner")
	handshake_spawner.spawned.connect(_on_player_spawned)
	handshake_spawner.despawned.connect(_on_player_despawned)

## Virtual method to get spawn parameters (position, rotation, etc).
## Must be implemented by subclasses.
func _get_spawn_params(_peer_id: int) -> Dictionary:
	push_error("BasePlayerSpawnManager: _get_spawn_params not implemented")
	return {}

func _on_player_ready_for_gameplay(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		return

	var params = _get_spawn_params(peer_id)
	handshake_spawner.spawn(player_spawner_label, params)

#region Player Callbacks

## Called when a player leaves the lobby.
func _on_player_left(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		# Server is responsible for announcing despawn to all peers
		var spawn_id = _spawned_players[peer_id].spawn_id
		handshake_spawner.despawn_id(spawn_id)

	_spawned_players.erase(peer_id)

func _on_player_spawned(_node: Node, request: SpawnRequest) -> void:
	var peer_id = request.params["peer_id"]
	_spawned_players[peer_id] = request

func _on_player_despawned(spawn_id: String) -> void:
	# For each player
	for peer_id in _spawned_players:
		var spawn_request = _spawned_players[peer_id]
		# If the spawn_id matches, forget the player
		if spawn_request.spawn_id == spawn_id:
			_spawned_players.erase(peer_id)
			break

#endregion
