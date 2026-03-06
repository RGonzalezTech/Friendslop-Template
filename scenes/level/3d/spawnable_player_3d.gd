class_name SpawnablePlayer3D
extends SpawnableResource

## The player scene to spawn
@export var player_scene: PackedScene

func spawn(params: Dictionary) -> Player3D:
	_validate_params(params)
	var player = player_scene.instantiate()
	player.position = params.get("position", Vector3.ZERO)
	player.peer_id = params["peer_id"]
	return player

func _validate_params(params: Dictionary) -> void:
	assert(player_scene != null, "SpawnablePlayer3D requires a player scene")
	assert(params.has("peer_id"), "SpawnablePlayer3D requires a peer_id")
	assert(params["peer_id"] is int, "SpawnablePlayer3D requires peer_id to be an int")
	if params.has("position"):
		assert(params["position"] is Vector3, "SpawnablePlayer3D requires position to be a Vector3")
