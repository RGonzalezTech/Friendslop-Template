class_name TestBasePlayerSpawnManager
extends GutTest

# Mock implementation of the abstract base class
class MockPlayerSpawnManager:
	extends BasePlayerSpawnManager
	
	var _mock_spawn_params: Dictionary = {}
	
	func _get_spawn_params(_peer_id: int) -> Dictionary:
		return _mock_spawn_params
	
	func set_mock_spawn_params(params: Dictionary) -> void:
		_mock_spawn_params = params

var _spawn_manager: MockPlayerSpawnManager
var _mock_level_root: NetworkLevelRoot
var _mock_handshake_spawner: HandshakeSpawner

func before_each():
	_mock_level_root = double(NetworkLevelRoot).new()
	_mock_handshake_spawner = double(HandshakeSpawner).new()
	
	# Create our mock manager
	_spawn_manager = MockPlayerSpawnManager.new()
	
	# Inject dependencies
	_spawn_manager.network_level_root = _mock_level_root
	_spawn_manager.handshake_spawner = _mock_handshake_spawner
	
	add_child_autofree(_spawn_manager)

func after_each():
	# Clean up doubles if they are strictly Nodes and not auto-freed by add_child_autofree
	# Usually doubles extending Node need to be freed if not added to tree.
	if is_instance_valid(_mock_level_root):
		_mock_level_root.free()
	if is_instance_valid(_mock_handshake_spawner):
		_mock_handshake_spawner.free()

func test_initialization():
	assert_not_null(_spawn_manager.network_level_root, "NetworkLevelRoot should be set")
	assert_not_null(_spawn_manager.handshake_spawner, "HandshakeSpawner should be set")

func test_spawn_player_on_ready_signal():
	# Setup
	var peer_id = 123
	var spawn_params = {"pos": Vector2(100, 100), "peer_id": peer_id}
	_spawn_manager.set_mock_spawn_params(spawn_params)
	
	# Trigger signal
	_mock_level_root.player_ready_for_gameplay.emit(peer_id)
	
	# Verification
	# handshake_spawner.spawn(label: String, params: Dictionary)
	assert_called(_mock_handshake_spawner, "spawn", [_spawn_manager.player_spawner_label, spawn_params])

func test_spawn_player_only_once():
	var peer_id = 456
	var spawn_params = {"pos": Vector2(200, 200), "peer_id": peer_id}
	_spawn_manager.set_mock_spawn_params(spawn_params)
	
	# First Call
	_mock_level_root.player_ready_for_gameplay.emit(peer_id)
	
	# Simulate the spawn completion to register the player internally
	var mock_node = Node.new()
	var mock_request = SpawnRequest.new()
	mock_request.params = spawn_params
	mock_request.spawn_id = "spawn_456"
	_spawn_manager._on_player_spawned(mock_node, mock_request)
	
	assert_called(_mock_handshake_spawner, "spawn", [_spawn_manager.player_spawner_label, spawn_params])
	
	# Second Call - should not spawn again
	# Clear previous calls to be sure
	# clear_signal_watcher(_mock_handshake_spawner) # Doesn't exist directly, but we check count
	
	_mock_level_root.player_ready_for_gameplay.emit(peer_id)
	
	# Should still be called exactly once
	assert_call_count(_mock_handshake_spawner, "spawn", 1)
	
	mock_node.free()

func test_player_left_despawns():
	var peer_id = 789
	var spawn_id = "spawn_789"
	var spawn_params = {"pos": Vector2(300, 300), "peer_id": peer_id}
	_spawn_manager.set_mock_spawn_params(spawn_params)
	
	# 1. Setup internal state (simulate successful spawn)
	var mock_node = Node.new()
	var mock_request = SpawnRequest.new()
	mock_request.spawn_id = spawn_id
	mock_request.params = spawn_params
	
	# Manually call callback or setup internal dictionary if possible
	# Since _spawned_players is private (conventionally), we use the callback
	_spawn_manager._on_player_spawned(mock_node, mock_request)
	
	# 2. Trigger player left
	# Use the global LobbyManager trigger if possible, or simulate the connection
	if LobbyManager.has_signal("player_left"):
		LobbyManager.player_left.emit(peer_id)
	else:
		fail_test("LobbyManager does not have player_left signal")
	
	# Verify despawn called
	assert_called(_mock_handshake_spawner, "despawn_id", [spawn_id])
	
	mock_node.free()

func test_internal_cleanup_on_despawned():
	var peer_id = 101
	var spawn_id = "spawn_101"
	var spawn_params = {"pos": Vector2(400, 400), "peer_id": peer_id}
	
	# 1. Setup internal state
	var mock_node = Node.new()
	var mock_request = SpawnRequest.new()
	mock_request.spawn_id = spawn_id
	mock_request.params = spawn_params
	_spawn_manager._on_player_spawned(mock_node, mock_request)
	
	# 2. Simulate despawn callback (e.g. from server command)
	_spawn_manager._on_player_despawned(spawn_id)
	
	# 3. Now if player leaves, it should NOT try to despawn again
	if LobbyManager.has_signal("player_left"):
		LobbyManager.player_left.emit(peer_id)
	
	# Verify despawn_id was NOT called (since _on_player_despawned doesn't call it, and player_left shouldn't either)
	assert_not_called(_mock_handshake_spawner, "despawn_id")
	
	mock_node.free()
