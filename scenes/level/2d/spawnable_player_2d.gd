class_name SpawnablePlayer2D
extends SpawnableResource

## The player scene to spawn
@export var player_scene: PackedScene

func spawn(params: Dictionary) -> Player2D:
	_validate_params(params)
	var player = player_scene.instantiate()
	player.position = params["position"]
	player.peer_id = params["peer_id"]
	return player

func _validate_params(params: Dictionary) -> void:
	assert(player_scene != null, "SpawnablePlayer2D requires a player scene")

	# Validate position
	assert(params.has("position"), "SpawnablePlayer2D requires a position")
	assert(params["position"] is Vector2, "SpawnablePlayer2D requires a position to be a Vector2")

	# Validate peer_id
	assert(params.has("peer_id"), "SpawnablePlayer2D requires a peer_id")
	assert(params["peer_id"] is int, "SpawnablePlayer2D requires a peer_id to be an int")
