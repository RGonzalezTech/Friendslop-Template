extends BaseNetworkGutTest

# --- Mocks ---

# Mock implementation of the abstract base class
class MockPlayerSpawnManager:
	extends BasePlayerSpawnManager
	
	var _mock_spawn_params: Dictionary = {}
	
	func _get_spawn_params(_peer_id: int) -> Dictionary:
		return _mock_spawn_params
	
	func set_mock_spawn_params(params: Dictionary) -> void:
		_mock_spawn_params = params

class MockSpawnableResource extends SpawnableResource:
	func spawn(params: Dictionary) -> Node:
		var n = Node.new()
		n.name = "MockPlayer"
		for key in params:
			n.set_meta(key, params[key])
		return n

# --- Variables ---

var _spawn_manager: MockPlayerSpawnManager
var _level_root: NetworkLevelRoot
var _handshake_spawner: HandshakeSpawner
var _spawn_container: Node

# --- Setup / Teardown ---

func before_each():
	setup_server()

	# 1. Setup Containers
	_spawn_container = Node.new()
	_spawn_container.name = "SpawnContainer"
	_server_node.add_child(_spawn_container)
	
	# 2. Setup Level Root (real or double if complex)
	_level_root = double(NetworkLevelRoot).new()
	
	# 3. Setup Real HandshakeSpawner
	_handshake_spawner = HandshakeSpawner.new()
	_handshake_spawner.spawn_path = _spawn_container.get_path()
	_handshake_spawner.spawnables["player"] = MockSpawnableResource.new()
	_server_node.add_child(_handshake_spawner)
	
	# 4. Setup Spawn Manager
	_spawn_manager = MockPlayerSpawnManager.new()
	_spawn_manager.network_level_root = _level_root
	_spawn_manager.handshake_spawner = _handshake_spawner
	_spawn_manager.player_spawner_label = "player"
	
	# Add to _server_node provided by BaseNetworkGutTest
	_server_node.add_child(_spawn_manager)
	
	# Wait for network setup
	await wait_seconds(0.1)

func after_each():
	if is_instance_valid(_spawn_container):
		_spawn_container.free()
	if is_instance_valid(_spawn_manager):
		_spawn_manager.free()
	if is_instance_valid(_handshake_spawner):
		_handshake_spawner.free()

# --- Helpers ---

func _simulate_player_ready_for_spawn(peer_id: int, spawn_params: Dictionary) -> void:
	_spawn_manager.set_mock_spawn_params(spawn_params)
	_level_root.player_ready_for_gameplay.emit(peer_id)

# --- Tests ---

func test_initialization():
	assert_not_null(_spawn_manager.network_level_root, "NetworkLevelRoot should be injected")
	assert_not_null(_spawn_manager.handshake_spawner, "HandshakeSpawner should be injected")

func test_spawn_player_on_ready_signal():
	var peer_id = 123
	var spawn_params = {"pos": Vector2(100, 100), "peer_id": peer_id}
	
	_simulate_player_ready_for_spawn(peer_id, spawn_params)
	
	await wait_seconds(0.2)
	
	assert_eq(_spawn_container.get_child_count(), 1, "A player should have been spawned in the container")
	var spawned_node = _spawn_container.get_child(0)
	assert_eq(spawned_node.get_meta("peer_id"), peer_id, "The spawned node should have the correct peer_id metadata")

func test_spawn_player_only_once():
	var peer_id = 456
	var spawn_params = {"pos": Vector2(200, 200), "peer_id": peer_id}
	
	_simulate_player_ready_for_spawn(peer_id, spawn_params)
	await wait_seconds(0.2)
	
	_level_root.player_ready_for_gameplay.emit(peer_id)
	await wait_seconds(0.1)
	
	assert_eq(_spawn_container.get_child_count(), 1, "Player should only be spawned once")

func test_player_left_despawns():
	var peer_id = 789
	var spawn_params = {"peer_id": peer_id}
	_simulate_player_ready_for_spawn(peer_id, spawn_params)
	await wait_seconds(0.2)
	assert_eq(_spawn_container.get_child_count(), 1, "Player should be spawned initially")
	
	LobbyManager.player_left.emit(peer_id)
	await wait_seconds(0.2)
	
	assert_eq(_spawn_container.get_child_count(), 0, "Player should be despawned after leaving")

func test_can_remove_same_peer_id_multiple_times_without_crashing():
	## This test verifies that removing a player multiple times (first via HandshakeSpawner
	## despawn, then via player_left signal) does not cause a crash and keeps the state clean.
	var peer_id = 101
	var spawn_params = {"peer_id": peer_id}
	
	_simulate_player_ready_for_spawn(peer_id, spawn_params)
	await wait_seconds(0.2)
	
	var spawned_node = _spawn_container.get_child(0)
	var spawn_id = spawned_node.get_meta("s_id")
	
	_handshake_spawner.despawn_id(spawn_id)
	await wait_seconds(0.2)
	
	assert_eq(_spawn_container.get_child_count(), 0, "Node should be despawned from the scene tree")
	
	LobbyManager.player_left.emit(peer_id)
	await wait_seconds(0.1)
	
	assert_eq(_spawn_container.get_child_count(), 0, "Container should remain empty after player_left signal")
