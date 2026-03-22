extends GutTest

var _lobby_player: LobbyPlayer

func before_each():
	_lobby_player = LobbyPlayer.new()
	add_child_autofree(_lobby_player)

func test_init_values():
	assert_eq(_lobby_player.peer_id, 0, "LobbyPlayer peer_id should be 0") # unassigned
	assert_eq(_lobby_player.local_player_id, LobbyPlayer.DEFAULT_LOCAL_PLAYER_ID, "LobbyPlayer local_player_id should be 0")
	assert_eq(_lobby_player.status, LobbyPlayer.Status.CONNECTING, "LobbyPlayer status should be CONNECTING")

func test_updates_name_on_peer_or_local_change():
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
