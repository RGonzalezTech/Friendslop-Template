extends GutTest

# --- Mocks ---
class MockSpawnableResource extends SpawnableResource:
	func spawn(params: Dictionary) -> Node:
		var n = Node.new()
		n.name = "MockUnit"
		n.set_meta("test_hp", params.get("hp", 0))
		return n
	
	func teardown(node: Node) -> void:
		node.queue_free()

# --- Network Setup Variables ---
var server_node: Node
var client_node: Node
var _server_peer: ENetMultiplayerPeer
var _client_peer: ENetMultiplayerPeer

const PORT = 8915
const LOCALHOST = "127.0.0.1"

# --- Test Variables ---
var server_spawner: HandshakeSpawner
var client_spawner: HandshakeSpawner
var server_container: Node
var client_container: Node
var mock_resource: MockSpawnableResource

func before_each():
	# 1. Setup Network Topology
	server_node = Node.new()
	server_node.name = "ServerRoot"
	add_child(server_node)
	
	client_node = Node.new()
	client_node.name = "ClientRoot"
	add_child(client_node)

	# 2. Setup Server Peer
	_server_peer = ENetMultiplayerPeer.new()
	_server_peer.create_server(PORT)
	var server_mp = SceneMultiplayer.new()
	server_mp.multiplayer_peer = _server_peer
	get_tree().set_multiplayer(server_mp, server_node.get_path())

	# 3. Setup Client Peer
	_client_peer = ENetMultiplayerPeer.new()
	_client_peer.create_client(LOCALHOST, PORT)
	var client_mp = SceneMultiplayer.new()
	client_mp.multiplayer_peer = _client_peer
	get_tree().set_multiplayer(client_mp, client_node.get_path())

	# 4. Setup Test Resources & Containers
	mock_resource = MockSpawnableResource.new()
	
	server_container = Node.new()
	server_container.name = "Entities"
	server_node.add_child(server_container)
	
	client_container = Node.new()
	client_container.name = "Entities"
	client_node.add_child(client_container)
	
	# 5. Setup Spawners
	server_spawner = HandshakeSpawner.new()
	server_spawner.name = "Spawner"
	server_spawner.spawn_path = server_container.get_path()
	server_spawner.spawnables["mock_unit"] = mock_resource
	server_node.add_child(server_spawner)
	
	client_spawner = HandshakeSpawner.new()
	client_spawner.name = "Spawner"
	client_spawner.spawn_path = client_container.get_path()
	client_spawner.spawnables["mock_unit"] = mock_resource
	client_node.add_child(client_spawner)

	# 6. Wait for connection
	await wait_seconds(0.1)

func after_each():
	if _server_peer: _server_peer.close()
	if _client_peer: _client_peer.close()
	server_node.free()
	client_node.free()

# --- Tests ---

func test_spawn_replicates_to_client():
	watch_signals(client_spawner)
	
	# 1. Server calls spawn
	server_spawner.spawn("mock_unit", {"hp": 100})
	
	# 2. Wait for RPC
	await wait_seconds(0.1)
	
	# 3. Verify Server side
	assert_eq(server_container.get_child_count(), 1, "Server should have spawned node")
	
	# 4. Verify Client side
	assert_eq(client_container.get_child_count(), 1, "Client should have spawned node")
	assert_signal_emitted(client_spawner, "spawned", "Client spawner should emit 'spawned'")
	
	if client_container.get_child_count() > 0:
		var node = client_container.get_child(0)
		assert_eq(node.get_meta("test_hp"), 100, "Spawn parameters should be passed")

func test_despawn_replicates_to_client():
	# Setup: Spawn something first
	server_spawner.spawn("mock_unit", {})
	await wait_seconds(0.1)
	
	var server_entity = server_container.get_child(0)
	var s_id = server_entity.get_meta("s_id")
	
	watch_signals(client_spawner)
	
	# 1. Server calls despawn
	server_spawner.despawn_id(s_id)
	
	# 2. Wait for RPC
	await wait_seconds(0.1)
	
	# 3. Verify
	assert_eq(client_container.get_child_count(), 0, "Client should have removed node")
	assert_signal_emitted(client_spawner, "despawned")

func test_late_join_catchup():
	# 1. Server spawns an entity BEFORE client is "ready"
	server_spawner.spawn("mock_unit", {"hp": 50})
	
	# HandshakeRetryTimer inside the client spawner should automatically 
	# request a replay since the nodes are newly added.
	
	# Wait for the catch-up handshake
	await wait_seconds(0.2)
	
	assert_eq(client_container.get_child_count(), 1, "Client should receive existing entities via catchup")
	
	if client_container.get_child_count() > 0:
		var node = client_container.get_child(0)
		assert_eq(node.get_meta("test_hp"), 50, "Catchup params should be correct")