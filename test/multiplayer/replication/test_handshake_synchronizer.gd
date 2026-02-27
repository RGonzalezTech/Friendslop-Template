extends BaseNetworkGutTest

func before_each():
	setup_server()
	setup_client()
	
	# Wait for connection
	await wait_seconds(0.1)

func after_each():
	# Clear test children from the base nodes
	for child in _server_node.get_children():
		child.free()
	for child in _client_node.get_children():
		child.free()

# --- Tests ---

func test_server_hides_visibility_by_default():
	var this_sync = HandshakeSynchronizer.new()
	_server_node.add_child(this_sync)
	
	assert_false(this_sync.public_visibility, "Server should set public_visibility to false on enter_tree")
	assert_false(this_sync.get_visibility_for(1), "Should not be visible to self initially")

func test_client_creates_retry_timer():
	var sync = HandshakeSynchronizer.new()
	_client_node.add_child(sync )
	
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
	_server_node.add_child(server_sync)
	
	# 2. Setup Client Side
	var client_sync = HandshakeSynchronizer.new()
	client_sync.name = "SyncNode"
	_client_node.add_child(client_sync)
	
	await wait_seconds(0.1)
	
	# 3. Trigger handshake manually or wait for timer
	# We manually trigger to ensure test speed/determinism
	client_sync._on_sync_requested()
	
	# 4. Allow RPCs to travel
	await wait_seconds(0.1)
	
	# 5. Verify Server State
	var client_peer_id = _server_node.multiplayer.get_peers()[0]
	assert_true(
		server_sync.get_visibility_for(client_peer_id),
		"Server should have granted visibility to the client"
	)
