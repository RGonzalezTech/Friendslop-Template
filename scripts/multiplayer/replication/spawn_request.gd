class_name SpawnRequest
extends RefCounted

## Represents an entity that has been spawned, as well as
## the parameters that were used to spawn it.

#region Synced Properties
## The spawn ID this entity was spawned with
var spawn_id: String
## The type of entity that was spawned (e.g. "enemy_grunt")
var type: String
## The parameters that were used to spawn the entity
var params: Dictionary
#endregion

#region Local Properties
## Local reference to the spawned node
var node: Object
#endregion

func _init(s_type: String = "", s_params: Dictionary = {}) -> void:
	spawn_id = new_id()
	type = s_type
	params = s_params

## Generates a new ID
static func new_id() -> String:
	var crypto := Crypto.new()
	var key := crypto.generate_random_bytes(16)
	return key.hex_encode()

## Converts the spawn data to a dictionary
func to_dict() -> Dictionary:
	return {
		"spawn_id": spawn_id,
		"type": type,
		"params": params
	}

## Validates a dictionary to ensure it contains the required keys
static func validate_dict(data: Dictionary) -> bool:
	return data.has("spawn_id") and data.has("type") and data.has("params")

## Converts a dictionary to spawn data
static func from_dict(data: Dictionary) -> SpawnRequest:
	assert(validate_dict(data), "Invalid spawn data")
	var new_spawn = SpawnRequest.new(data.type, data.params)
	new_spawn.spawn_id = data.spawn_id
	return new_spawn
