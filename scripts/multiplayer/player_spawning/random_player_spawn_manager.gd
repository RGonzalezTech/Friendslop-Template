class_name RandomPlayerSpawnManager
extends BasePlayerSpawnManager

## Implementation for simple random spawning.
## Picks a random child from `spawn_points` and uses its global_position.

@export var spawn_points: Node

func _get_spawn_params(peer_id: int) -> Dictionary:
	if spawn_points and spawn_points.get_child_count() > 0:
		var index = randi() % spawn_points.get_child_count()
		return {
			"position": spawn_points.get_child(index).global_position,
			"peer_id": peer_id
		}
	return {
		"position": Vector2.ZERO,
		"peer_id": peer_id
	}
