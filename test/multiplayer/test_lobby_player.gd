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
