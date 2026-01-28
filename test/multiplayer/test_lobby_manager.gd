extends GutTest

var _lobby_manager: LobbyManagerCode
var _mock_peer: ENetMultiplayerPeer
var _mock_scene_manager: SceneManagerCode

func before_each():
	_lobby_manager = LobbyManagerCode.new()
	
	# Dependency Injection for SceneManager
	_mock_scene_manager = double(SceneManagerCode).new()
	
	add_child_autofree(_lobby_manager)
	
	# OnReady sets the scene manager, so we need to set it after adding to tree
	_lobby_manager.scene_manager = _mock_scene_manager
	
	# Default to no peer or a clean state
	multiplayer.multiplayer_peer = null
	_mock_peer = null

func after_each():
	multiplayer.multiplayer_peer = null
	_mock_scene_manager.free()

func test_reset_lobby_clears_players_and_state():
	# Setup "Nuclear" scenario
	# Add a child node manually to simulate players
	var dummy_player = Node.new()
	dummy_player.name = "999"
	_lobby_manager._lobby_players_container.add_child(dummy_player)
	
	_lobby_manager.current_lobby.host_id = 999
	_lobby_manager.current_lobby.state = Lobby.State.IN_GAME
	
	_lobby_manager.reset_lobby()
	
	# reset_lobby uses queue_free, so we must wait for it to be processed
	await wait_seconds(0.1)
	
	assert_eq(_lobby_manager._lobby_players_container.get_child_count(), 0, "LobbyPlayers container should be empty")
	assert_eq(_lobby_manager.current_lobby.host_id, 1, "Host ID should reset to 1")
	assert_eq(_lobby_manager.current_lobby.state, Lobby.State.NOT_CONNECTED, "State should be NOT_CONNECTED")

func test_initialize_lobby_as_host_sets_server_state():
	# Mock is_server() by setting a server peer
	_mock_peer = ENetMultiplayerPeer.new()
	_mock_peer.create_server(8911)
	multiplayer.multiplayer_peer = _mock_peer
	
	# Verify setup
	assert_true(multiplayer.is_server(), "Should be server")
	
	_lobby_manager.initialize_lobby_as_host()
	
	assert_eq(_lobby_manager.current_lobby.host_id, multiplayer.get_unique_id(), "Host ID should match local ID")
	
	# Check if player was added
	var players = _lobby_manager.get_all_players()
	assert_eq(players.size(), 1, "Should have 1 player (host)")
	assert_eq(players[0].peer_id, multiplayer.get_unique_id(), "Player ID should match host")

func test_spawn_player_configures_lobby_player():
	var result = _lobby_manager._spawn_player(123)
	
	assert_not_null(result, "Spawn result should not be null")
	assert_is(result, LobbyPlayer, "Result should be LobbyPlayer")
	assert_eq(result.peer_id, 123, "Peer ID should be 123")
	assert_eq(result.name, "123", "Node name should be '123'")
	
	# _spawn_player returns a node but doesn't add it to tree (MultiplayerSpawner does that)
	# So we should free it manually to avoid leaks, as success/failures might leave it dangling?
	# result is an Object.
	result.free()

func test_scene_transition_on_map_change():
	var test_path = "res://scenes/maps/TestMap.tscn"
	
	# Trigger map change
	_lobby_manager.current_lobby.active_map_path = test_path
	
	# Assert that SceneManager.start_transition_to was called with the correct path
	assert_called(_mock_scene_manager.start_transition_to.bind(test_path))

func test_player_state_api_toggles_ready_and_updates_name():
	# Setup server environment
	_mock_peer = ENetMultiplayerPeer.new()
	_mock_peer.create_server(8911)
	multiplayer.multiplayer_peer = _mock_peer
	
	_lobby_manager.initialize_lobby_as_host()
	var local_player = _lobby_manager.get_local_player()
	
	assert_not_null(local_player, "Local player should exist after host init")
	assert_eq(local_player.peer_id, multiplayer.get_unique_id(), "Peer ID should match local machine")
	
	# Test toggle_ready
	var initial_ready = local_player.is_ready
	_lobby_manager.toggle_ready()
	assert_eq(local_player.is_ready, !initial_ready, "Ready state should be toggled")
	_lobby_manager.toggle_ready()
	assert_eq(local_player.is_ready, initial_ready, "Ready state should be toggled back")
	
	# Test update_player_name
	var new_name = "NewPlayerName"
	_lobby_manager.update_player_name(new_name)
	assert_eq(local_player.player_name, new_name, "Player name should be updated")

func test_internal_signals_emit_player_joined_and_left():
	watch_signals(_lobby_manager)
	
	# Manual node addition (simulates MultiplayerSpawner behavior)
	var p_id = 123
	var p_node = LobbyPlayer.new()
	p_node.peer_id = p_id
	
	_lobby_manager._lobby_players_container.add_child(p_node)
	assert_signal_emitted_with_parameters(_lobby_manager.player_joined, [p_id])
	
	_lobby_manager._lobby_players_container.remove_child(p_node)
	assert_signal_emitted_with_parameters(_lobby_manager.player_left, [p_id])
	p_node.free()

func test_network_events_spawn_and_remove_players():
	# Mock server
	_mock_peer = ENetMultiplayerPeer.new()
	_mock_peer.create_server(8911)
	multiplayer.multiplayer_peer = _mock_peer
	
	# Test _on_peer_connected
	var peer_id = 456
	_lobby_manager._on_peer_connected(peer_id)
	
	# Since _on_peer_connected calls _add_player which calls _lobby_player_spawner.spawn(peer_id),
	# and we are the server, it should spawn it immediately.
	var p = _lobby_manager.get_player(peer_id)
	assert_not_null(p, "Player node should be spawned for connected peer")
	
	# Test _on_peer_disconnected
	_lobby_manager._on_peer_disconnected(peer_id)
	await wait_seconds(0.1) # queue_free
	assert_null(_lobby_manager.get_player(peer_id), "Player node should be removed for disconnected peer")

func test_connection_shutdown_resets_lobby_and_returns_to_menu():
	var reason = "Kicked for being too cool"
	_lobby_manager._on_connection_shutdown(reason)
	
	assert_eq(_lobby_manager.disconnection_reason, reason, "Reason should be stored")
	assert_called(_mock_scene_manager.go_to_main_menu)
	# Verify lobby reset
	assert_eq(_lobby_manager.current_lobby.state, Lobby.State.NOT_CONNECTED)

func test_scene_load_failed_returns_to_menu_with_reason():
	var reason = "File corrupted"
	_lobby_manager._on_scene_load_failed(reason)
	
	assert_eq(_lobby_manager.disconnection_reason, reason, "Reason should be stored")
	assert_called(_mock_scene_manager.go_to_main_menu)
