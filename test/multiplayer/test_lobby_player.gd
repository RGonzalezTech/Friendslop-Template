extends GutTest

var _lobby_player: LobbyPlayer

func before_each():
	_lobby_player = LobbyPlayer.new()
	add_child(_lobby_player)

func after_each():
	_lobby_player.free()

func test_authority_distribution():
	_lobby_player.peer_id = 456
	
	assert_eq(_lobby_player.get_multiplayer_authority(), 456, "LobbyPlayer authority should match peer_id")
	
	assert_not_null(_lobby_player._player_sync, "Player sync should exist")
	assert_eq(_lobby_player._player_sync.get_multiplayer_authority(), 456, "Player sync authority should match peer_id")
	
	assert_not_null(_lobby_player._server_sync, "Server sync should exist")
	assert_eq(_lobby_player._server_sync.get_multiplayer_authority(), 1, "Server sync authority should be 1 (Server)")
