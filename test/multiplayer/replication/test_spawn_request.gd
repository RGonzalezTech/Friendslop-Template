extends GutTest

func test_initialization_generates_id():
	var req = SpawnRequest.new("enemy", {"hp": 100})
	assert_not_null(req.spawn_id, "Spawn ID should be generated")
	assert_gt(req.spawn_id.length(), 0, "Spawn ID should not be empty")
	assert_eq(req.type, "enemy", "Type should be set")
	assert_eq(req.params.hp, 100, "Params should be set")

func test_to_dict_contains_all_fields():
	var req = SpawnRequest.new("player", {"id": 1})
	var data = req.to_dict()
	
	assert_true(data.has("spawn_id"), "Dict should have spawn_id")
	assert_true(data.has("type"), "Dict should have type")
	assert_true(data.has("params"), "Dict should have params")
	
	assert_eq(data.spawn_id, req.spawn_id)
	assert_eq(data.type, "player")
	assert_eq(data.params.id, 1)

func test_validate_dict():
	var valid = {
		"spawn_id": "123",
		"type": "t",
		"params": {}
	}
	assert_true(SpawnRequest.validate_dict(valid), "Should be valid")
	
	var invalid = {
		"type": "t",
		"params": {}
	}
	assert_false(SpawnRequest.validate_dict(invalid), "Should be invalid (missing spawn_id)")

func test_from_dict_reconstructs_object():
	var original_id = "test_id_123"
	var data = {
		"spawn_id": original_id,
		"type": "crate",
		"params": {"loot": "gold"}
	}
	
	var req = SpawnRequest.from_dict(data)
	
	assert_not_null(req, "Should return instance")
	assert_eq(req.spawn_id, original_id, "ID should match")
	assert_eq(req.type, "crate", "Type should match")
	assert_eq(req.params.loot, "gold", "Params should match")

func test_ids_are_unique():
	var req1 = SpawnRequest.new()
	var req2 = SpawnRequest.new()
	assert_ne(req1.spawn_id, req2.spawn_id, "IDs should be unique")
