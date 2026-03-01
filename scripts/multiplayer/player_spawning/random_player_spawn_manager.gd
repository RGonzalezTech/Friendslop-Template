class_name RandomPlayerSpawnManager
extends BasePlayerSpawnManager

## Implementation for random spawning that avoids placing two players
## on the same spawn point.  Picks an unused child from `spawn_points`
## at random; if every point is occupied it falls back to any random point.

@export var spawn_points: Node

## Maps spawn-point child index -> peer_id currently using it.
var _used_indices: Dictionary[int, int] = {}

func _get_spawn_params(peer_id: int) -> Dictionary:
	if spawn_points and spawn_points.get_child_count() > 0:
		var index = _pick_available_index()
		_used_indices[index] = peer_id
		return {
			"position": spawn_points.get_child(index).global_position,
			"peer_id": peer_id
		}
	return {
		"peer_id": peer_id
	}

## When a player leaves, free their spawn point so it can be reused.
func _on_player_left(peer_id: int) -> void:
	_release_index_for_peer(peer_id)
	super._on_player_left(peer_id)

func _release_index_for_peer(peer_id: int) -> void:
	for idx in _used_indices:
		if _used_indices[idx] == peer_id:
			_used_indices.erase(idx)
			return

## Returns a random unused spawn-point index, or any random index if all
## are occupied.
func _pick_available_index() -> int:
	var count = spawn_points.get_child_count()
	var available: Array[int] = []
	for i in count:
		if not _used_indices.has(i):
			available.append(i)

	if available.size() > 0:
		return available[randi() % available.size()]

	# All points occupied – fall back to pure random.
	return randi() % count
