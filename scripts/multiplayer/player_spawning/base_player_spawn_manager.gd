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

## Nested dictionary mapping peer_id -> { local_player_id -> SpawnRequest }
var _spawned_players: Dictionary[int, Dictionary] = {}

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
func _get_spawn_params(_peer_id: int, _local_player_id: int) -> Dictionary:
	push_error("BasePlayerSpawnManager: _get_spawn_params not implemented")
	return {}

func _on_player_ready_for_gameplay(peer_id: int, local_player_id: int) -> void:
	var players_for_peer = _spawned_players.get(peer_id, {})
	if players_for_peer.has(local_player_id):
		return

	var params = _get_spawn_params(peer_id, local_player_id)
	_validate_params(params)
	handshake_spawner.spawn(player_spawner_label, params)

# Ensures that _get_spawn_params() returns valid parameters
func _validate_params(params: Dictionary) -> void:
	var peer_id = params.get("peer_id")
	_validate_peer_id(peer_id)

#region Player Callbacks

## Called when a player leaves the lobby.
func _on_player_left(peer_id: int, local_player_id: int) -> void:
	var players_for_peer = _spawned_players.get(peer_id, {})
	if players_for_peer.has(local_player_id):
		# Server is responsible for announcing despawn to all peers
		var spawn_id = players_for_peer[local_player_id].spawn_id
		handshake_spawner.despawn_id(spawn_id)

	players_for_peer.erase(local_player_id)
	if players_for_peer.is_empty():
		_spawned_players.erase(peer_id)

func _on_player_spawned(_node: Node, request: SpawnRequest) -> void:
	var peer_id = request.params["peer_id"]
	var local_player_id = request.params.get("local_player_id", 0)
	_validate_peer_id(peer_id)
	var peer_dict: Dictionary = _spawned_players.get_or_add(peer_id, {})
	peer_dict[local_player_id] = request

func _on_player_despawned(spawn_id: String) -> void:
	for peer_id in _spawned_players:
		var peer_dict = _spawned_players[peer_id]
		for local_id in peer_dict:
			if peer_dict[local_id].spawn_id == spawn_id:
				peer_dict.erase(local_id)
				if peer_dict.is_empty():
					_spawned_players.erase(peer_id)
				return

#endregion

func _validate_peer_id(peer_id: int) -> void:
	assert(peer_id is int, "BasePlayerSpawnManager: Players must be spawned with peer_id int")
	assert(peer_id > 0, "BasePlayerSpawnManager: Players peer_id must be greater than 0")