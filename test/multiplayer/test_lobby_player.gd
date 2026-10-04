extends GutTest

var _lobby_player: LobbyPlayer

func before_each():
	_lobby_player = LobbyPlayer.new()
	add_child_autofree(_lobby_player)

func test_init_values():
	assert_eq(_lobby_player.peer_id, 0, "LobbyPlayer peer_id should be 0") # unassigned
	assert_eq(_lobby_player.local_player_id, LobbyPlayer.DEFAULT_LOCAL_PLAYER_ID, "LobbyPlayer local_player_id should be 0")
	assert_eq(_lobby_player.status, LobbyPlayer.Status.CONNECTING, "LobbyPlayer status should be CONNECTING")
	assert_eq(_lobby_player.player_name, "Peer 0", "LobbyPlayer name should be Peer 0 by default")

func test_can_only_change_player_name_on_host_local_id():
	_lobby_player.player_name = "Example Name"
	assert_eq(_lobby_player.player_name, "Example Name", "player_name should be updated when local_player_id = 0")

	_lobby_player.peer_id = 10
	_lobby_player.player_name = "Another Example"
	assert_eq(_lobby_player.player_name, "Another Example", "player_name should be updated when peer_id = 10")

	# Parent player 
	var parent_lobby_player = LobbyPlayer.new()
	parent_lobby_player.peer_id = 10
	parent_lobby_player.player_name = "Parent Example Name"
	add_child_autofree(parent_lobby_player)

	_lobby_player._parent_lobby_player = parent_lobby_player
	_lobby_player.local_player_id = 2
	_lobby_player.player_name = "Should Not Update"
	assert_eq(_lobby_player.player_name, "Parent Example Name (2)", "player_name should return parent_name + local_player_id")

	parent_lobby_player.player_name = "Parent was changed"
	assert_eq(_lobby_player.player_name, "Parent was changed (2)", "player_name should update when parent_name changes")

func test_updates_node_name_on_peer_or_local_change():
	watch_signals(_lobby_player)
	assert_signal_not_emitted(_lobby_player.info_changed)

	_lobby_player.peer_id = 456
	assert_eq(_lobby_player.name, "456_0", "LobbyPlayer name should be updated when peer_id is set")
	
	_lobby_player.local_player_id = 1
	assert_eq(_lobby_player.name, "456_1", "LobbyPlayer name should be updated when local_player_id is set")

	_lobby_player.peer_id = 990
	assert_eq(_lobby_player.name, "990_1", "LobbyPlayer name should be updated when peer_id is set")

	_lobby_player.local_player_id = 2
	assert_eq(_lobby_player.name, "990_2", "LobbyPlayer name should be updated when local_player_id is set")

	_lobby_player.local_player_id = 2 # Should not trigger info_changed
	assert_signal_emit_count(_lobby_player.info_changed, 4)

func test_authority_distribution():
	_lobby_player.peer_id = 456
	
	assert_eq(_lobby_player.get_multiplayer_authority(), 1, "LobbyPlayer authority should be 1 (Server)")
	
	assert_not_null(_lobby_player._server_sync, "Server sync should exist")
	assert_eq(_lobby_player._server_sync.get_multiplayer_authority(), 1, "Server sync authority should be 1 (Server)")

func test_parent_lobby_player_info_relay():
	var parent_a = LobbyPlayer.new()
	var parent_b = LobbyPlayer.new()
	add_child_autofree(parent_a)
	add_child_autofree(parent_b)

	watch_signals(_lobby_player)

	# Set parent A
	_lobby_player._parent_lobby_player = parent_a
	assert_signal_emit_count(_lobby_player.info_changed, 1, "Should emit info_changed once when setting parent A")
	
	# Verify A -> _lobby_player signal propagation
	parent_a.info_changed.emit()
	assert_signal_emit_count(_lobby_player.info_changed, 2, "Should emit info_changed again when parent A emits it")

	# Set parent B (should disconnect from A, connect to B)
	_lobby_player._parent_lobby_player = parent_b
	assert_signal_emit_count(_lobby_player.info_changed, 3, "Should emit info_changed when changing to parent B")

	# Verify A no longer propagates
	parent_a.info_changed.emit()
	assert_signal_emit_count(_lobby_player.info_changed, 3, "Should NOT emit info_changed when old parent A emits it")

	# Verify B propagates
	parent_b.info_changed.emit()
	assert_signal_emit_count(_lobby_player.info_changed, 4, "Should emit info_changed when parent B emits it")

	# Set parent to null
	_lobby_player._parent_lobby_player = null
	assert_signal_emit_count(_lobby_player.info_changed, 5, "Should emit info_changed when setting parent to null")

	# Verify B no longer propagates
	parent_b.info_changed.emit()
	assert_signal_emit_count(_lobby_player.info_changed, 5, "Should NOT emit info_changed when old parent B emits it")

class TestLobbyPlayerNetworkStatus:
	extends BaseNetworkGutTest

	var _client_peer_id: int = -1
	var server_lobby_player: LobbyPlayer
	var client_lobby_player: LobbyPlayer

	func before_each():
		# Create server's copy of the node tree
		server_lobby_player = LobbyPlayer.new()
		server_lobby_player.peer_id = 1
		server_lobby_player.local_player_id = 0
		_server_node.add_child(server_lobby_player)
		# Spin up a server
		setup_server()

		# Create client's copy of the node tree
		client_lobby_player = LobbyPlayer.new()
		client_lobby_player.peer_id = 1
		client_lobby_player.local_player_id = 0
		_client_node.add_child(client_lobby_player)
		# Connect to the server
		setup_client()

		await wait_seconds(0.2) # wait for network connection
		_client_peer_id = client_lobby_player.multiplayer.get_unique_id()
		# This lobby player represents the client. 
		# Synchronized both client & server node trees
		server_lobby_player.peer_id = _client_peer_id
		client_lobby_player.peer_id = _client_peer_id
	
	func after_each():
		# Shut down servers
		teardown_client()
		teardown_server()
	
		# Remove if still present
		if is_instance_valid(client_lobby_player):
			client_lobby_player.free()
		if is_instance_valid(server_lobby_player):
			server_lobby_player.free()

	func test_set_status_is_server_side_and_peer_authenticated():
		assert_eq(server_lobby_player.status, LobbyPlayer.Status.CONNECTING, "LobbyPlayer should start with Connecting")

		# The server cannot send itself the request because the LobbyPlayer
		# does not represent the server.
		server_lobby_player.set_status.rpc_id(1, LobbyPlayer.Status.IN_GAME)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_eq(server_lobby_player.status, LobbyPlayer.Status.CONNECTING, "Server copy should not change")

		# The client should send the request to the server
		# And this should go through because the LobbyPlayer represents the client
		client_lobby_player.set_status.rpc_id(1, LobbyPlayer.Status.IN_GAME)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_eq(server_lobby_player.status, LobbyPlayer.Status.IN_GAME, "Server copy should change")

	func test_set_status_emits_status_changed():
		watch_signals(server_lobby_player)
		assert_signal_not_emitted(server_lobby_player.status_changed)
		
		server_lobby_player.set_status.rpc_id(1, LobbyPlayer.Status.IN_GAME)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_signal_not_emitted(server_lobby_player.status_changed, "Server cannot request on behalf of user")

		client_lobby_player.set_status.rpc_id(1, LobbyPlayer.Status.IN_GAME)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_signal_emitted_with_parameters(server_lobby_player.status_changed, [LobbyPlayer.Status.IN_GAME])

	func test_update_player_name_runs_update_player_name_rpc_on_host():
		watch_signals(server_lobby_player)
		var new_name = "New Name"
		
		# Server cannot update client's name directly via RPC (sender must be peer_id)
		server_lobby_player.update_player_name.rpc_id(1, new_name)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_ne(server_lobby_player.player_name, new_name, "Server should not be able to update client's name via RPC sender check")
		
		# Client should send the request to the server
		client_lobby_player.update_player_name.rpc_id(1, new_name)
		await wait_seconds(0.2) # Allow network frames to pass
		assert_eq(server_lobby_player.player_name, new_name, "Server copy should change when client calls RPC")
		assert_signal_emitted(server_lobby_player.info_changed)
