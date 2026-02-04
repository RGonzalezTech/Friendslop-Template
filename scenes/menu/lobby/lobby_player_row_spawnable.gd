class_name LobbyPlayerRowSpawnable
extends SpawnableResource

## The scene responsible for rendering a player row in the Lobby
const ROW_SCENE = preload("res://scenes/menu/lobby/LobbyPlayerRow.tscn")

func spawn(params: Dictionary) -> Control:
	_validate_params(params)
	var row = ROW_SCENE.instantiate()
	row.peer_id = params["peer_id"]
	return row

# Make sure that we have a peer_id
func _validate_params(params: Dictionary) -> void:
	assert(params.has("peer_id"), "LobbyPlayerRowSpawnable: spawn() requires peer_id")
	assert(params["peer_id"] > 0, "LobbyPlayerRowSpawnable: spawn() requires peer_id > 0")
