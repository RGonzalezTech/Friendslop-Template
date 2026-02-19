extends GutTest

# --- Network Setup Variables ---
var server_node: Node
var client_node: Node
var _server_peer: ENetMultiplayerPeer
var _client_peer: ENetMultiplayerPeer

const PORT = 8916 # Use a different port just in case
const LOCALHOST = "127.0.0.1"

func before_each():
	# 1. Create the root nodes for each "peer"
	server_node = Node.new()
	server_node.name = "ServerRoot"
	add_child(server_node)
	
	client_node = Node.new()
	client_node.name = "ClientRoot"
	add_child(client_node)

	# 2. Setup Server Network
	_server_peer = ENetMultiplayerPeer.new()
	_server_peer.create_server(PORT)
	var server_mp = SceneMultiplayer.new()
	server_mp.multiplayer_peer = _server_peer
	get_tree().set_multiplayer(server_mp, server_node.get_path())

	# 3. Setup Client Network
	_client_peer = ENetMultiplayerPeer.new()
	_client_peer.create_client(LOCALHOST, PORT)
	var client_mp = SceneMultiplayer.new()
	client_mp.multiplayer_peer = _client_peer
	get_tree().set_multiplayer(client_mp, client_node.get_path())

	# 4. Wait for connection
	await wait_seconds(0.1)

func after_each():
	if _server_peer: _server_peer.close()
	if _client_peer: _client_peer.close()
	server_node.free()
	client_node.free()

# --- Tests ---

func test_server_hides_visibility_by_default():
	var this_sync = HandshakeSynchronizer.new()
	server_node.add_child(this_sync)
	
	assert_false(this_sync.public_visibility, "Server should set public_visibility to false on enter_tree")
	assert_false(this_sync.get_visibility_for(1), "Should not be visible to self initially")

func test_client_creates_retry_timer():
	var sync = HandshakeSynchronizer.new()
	client_node.add_child(sync )
	
	# Verify internal child
	var has_timer = false
	for child in sync.get_children():
		if child is HandshakeRetryTimer:
			has_timer = true
			break
			
	assert_true(has_timer, "Client should add a HandshakeRetryTimer child")

func test_handshake_flow_grants_visibility():
	# 1. Setup Server Side
	var server_sync = HandshakeSynchronizer.new()
	server_sync.name = "SyncNode"
	server_node.add_child(server_sync)
	
	# 2. Setup Client Side
	var client_sync = HandshakeSynchronizer.new()
	client_sync.name = "SyncNode"
	client_node.add_child(client_sync)
	
	await wait_seconds(0.1)
	
	# 3. Trigger handshake manually or wait for timer
	# We manually trigger to ensure test speed/determinism
	client_sync._on_sync_requested()
	
	# 4. Allow RPCs to travel
	await wait_seconds(0.1)
	
	# 5. Verify Server State
	var client_peer_id = server_node.multiplayer.get_peers()[0]
	assert_true(
		server_sync.get_visibility_for(client_peer_id),
		"Server should have granted visibility to the client"
	)