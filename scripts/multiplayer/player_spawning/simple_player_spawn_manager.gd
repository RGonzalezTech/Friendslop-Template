class_name SimplePlayerSpawnManager
extends BasePlayerSpawnManager

## Simple implementation of BasePlayerSpawnManager
## Only passes the peer_id to the spawnable resource.
## The spawnable resource is responsible for getting the rest of the data.

func _get_spawn_params(peer_id: int) -> Dictionary:
	return {"peer_id": peer_id}
