extends BaseNetworkGutTest

var _lobby_manager: LobbyManagerCode
var _mock_scene_manager: SceneManagerCode

func before_each():
	setup_server()
	_lobby_manager = LobbyManagerCode.new()
	
	# Dependency Injection for SceneManager
	_mock_scene_manager = double(SceneManagerCode).new()
	
	_server_node.add_child(_lobby_manager)
	
	# OnReady sets the scene manager, so we need to set it after adding to tree
	_lobby_manager.scene_manager = _mock_scene_manager

func after_each():
	teardown_server()
	_mock_scene_manager.free()
	if _lobby_manager:
		_lobby_manager.free()

#region Lobby Setup

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
	await wait_process_frames(2)
	
	assert_eq(_lobby_manager._lobby_players_container.get_child_count(), 0, "LobbyPlayers container should be empty")
	assert_eq(_lobby_manager.current_lobby.host_id, 1, "Host ID should reset to 1")
	assert_eq(_lobby_manager.current_lobby.state, Lobby.State.NOT_CONNECTED, "State should be NOT_CONNECTED")

func test_initialize_lobby_as_host_sets_server_state():
	# Verify setup
	assert_true(_lobby_manager.multiplayer.is_server(), "Should be server")
	
	_lobby_manager.initialize_lobby_as_host()
	
	assert_eq(_lobby_manager.current_lobby.host_id, _lobby_manager.multiplayer.get_unique_id(), "Host ID should match local ID")
	
	# Check if player was added
	var players = _lobby_manager.get_all_players()
	assert_eq(players.size(), 1, "Should have 1 player (host)")
	assert_eq(players[0].peer_id, _lobby_manager.multiplayer.get_unique_id(), "Player ID should match host")

#endregion

#region LobbyPlayer Handling

const PEER_IDS = [1, 20, 123, 456, 789, 10]
func test_creates_lobby_player_from_peer_id(peer_id = use_parameters(PEER_IDS)):
	var lobby_player = _lobby_manager.create_player(peer_id)
	assert_is(lobby_player, LobbyPlayer, "Lobby player should be a LobbyPlayer")
	assert_eq(lobby_player.peer_id, peer_id, "Lobby player peer ID should be %d" % [peer_id])
	assert_eq(lobby_player.local_player_id, DEFAULT_LOCAL_PLAYER_ID, "Lobby player local player ID should be %d" % [DEFAULT_LOCAL_PLAYER_ID])
	lobby_player.free()

func test_creates_guest_lobby_player_if_parent_exists(peer_id = use_parameters(PEER_IDS)):
	var lobby_player_before_parent = _lobby_manager.create_player(peer_id, 1)
	assert_null(lobby_player_before_parent, "Lobby player should be null before parent exists")
	
	# Create parent node
	var parent = _lobby_manager.create_player(peer_id)
	assert_not_null(parent, "Parent should not be null")
	assert_eq(parent.local_player_id, DEFAULT_LOCAL_PLAYER_ID, "Parent local player ID should be default")
	
	# "Spawn" it
	_lobby_manager._lobby_players_container.add_child(parent)
	
	var lobby_player = _lobby_manager.create_player(peer_id, 1)
	assert_is(lobby_player, LobbyPlayer, "Lobby player should be a LobbyPlayer")
	assert_eq(lobby_player.peer_id, peer_id, "Lobby player peer ID should be %d" % [peer_id])
	assert_eq(lobby_player.local_player_id, 1, "Lobby player local player ID should be 1")
	assert_eq(lobby_player._parent_lobby_player, parent, "Lobby player should have parent")
	lobby_player.free()
	parent.free()

const DEFAULT_LOCAL_PLAYER_ID = LobbyPlayer.DEFAULT_LOCAL_PLAYER_ID
# Peer ID, Local Player ID
const SPAWN_PARAMS: Array = [
	[1, DEFAULT_LOCAL_PLAYER_ID],
	[20, DEFAULT_LOCAL_PLAYER_ID],
	[123, -1],
	[456, 1],
	[789, 2],
	[10, 3]
]
# We just test with local_player_id = 0
# Because otherwise, we have to setup the environment
func test_spawn_function_creates_lobby_player():
	var peer_id = 2
	var result = _lobby_manager._spawn_player([peer_id, 0])
	
	assert_not_null(result, "Spawn result should not be null")
	assert_is(result, LobbyPlayer, "Result should be LobbyPlayer")
	assert_eq(result.peer_id, peer_id, "Peer ID should be %d" % [peer_id])
	assert_eq(result.local_player_id, 0, "Device index should be 0")
	# _spawn_player returns a node but doesn't add it to tree (MultiplayerSpawner does that)
	# So we should free it manually to avoid leaks, as success/failures might leave it dangling?
	# result is an Object.
	result.free()

func test_get_players_by_peer_id(params = use_parameters(SPAWN_PARAMS)):
	var peer_id = params[0]
	var local_player_id = params[1]

	# We want to add a player with peer_id, local_player_id
	# and make sure that get_players(peer_id), returns a dictionary
	# with local_player_id mapped to the player node.
	
	assert_eq(_lobby_manager.get_players(peer_id), {}, "No players should be found for peer %d" % [peer_id])

	var result = _add_player(peer_id, local_player_id)

	var found_players = _lobby_manager.get_players(peer_id)
	assert_eq(found_players.size(), 1, "Should have 1 player for peer %d" % [peer_id])
	assert_eq(found_players[local_player_id], result, "Player node should be retrieved")

	# cleanup
	result.queue_free()
	await wait_process_frames(2)

	# test that the player is no longer found
	assert_eq(_lobby_manager.get_players(peer_id), {}, "No players should be found for peer %d" % [peer_id])

func test_gets_player_by_peer_and_local_id(params = use_parameters(SPAWN_PARAMS)):
	var peer_id = params[0]
	var local_player_id = params[1]
	
	assert_null(_lobby_manager.get_player(peer_id, local_player_id), "Player node should not exist before peer is connected")

	# manually spawn and add player
	var result = _add_player(peer_id, local_player_id)

	assert_eq(_lobby_manager.get_player(peer_id, local_player_id), result, "Player node should be retrieved")

	# cleanup
	result.queue_free()
	await wait_process_frames(2)
	assert_null(_lobby_manager.get_player(peer_id, local_player_id), "Player node should be removed for disconnected peer")

func test_get_local_player_returns_peer_one():
	var local_id = DEFAULT_LOCAL_PLAYER_ID
	assert_null(_lobby_manager.get_local_player(local_id), "Should not find local player before they exist")

	# p1 is another player (peer_id != 1)
	var p1 = _add_player(5, local_id)

	assert_null(_lobby_manager.get_local_player(local_id), "Should still not find local player (peer 5 != 1)")
	assert_eq(_lobby_manager.get_all_players().size(), 1, "Should have 1 total players, though not local")

	var p2 = _add_player(1, local_id)

	assert_eq(_lobby_manager.get_local_player(local_id), p2, "Should return the local player (peer 1)")
	assert_eq(_lobby_manager.get_all_players().size(), 2, "Should have 2 total players, including local")

	p1.queue_free()
	await wait_process_frames(2)

	assert_eq(_lobby_manager.get_local_player(local_id), p2, "Should still return the local player")
	assert_eq(_lobby_manager.get_all_players().size(), 1, "Should have 1 total players, including local")

	p2.queue_free()
	await wait_process_frames(2)

	assert_null(_lobby_manager.get_local_player(local_id), "Should not find local player after removal")
	assert_eq(_lobby_manager.get_all_players().size(), 0, "Should have 0 total players")

func test_get_local_players_returns_peer_one():
	assert_eq(_lobby_manager.get_local_players().size(), 0, "Should have 0 local players")

	# p1 is another player (peer_id != 1)
	var p1 = _add_player(5, 0)

	assert_eq(_lobby_manager.get_local_players().size(), 0, "Should still have 0 local players")
	assert_eq(_lobby_manager.get_all_players().size(), 1, "Should have 1 total players, though not local")

	var p2 = _add_player(1, 0)

	assert_eq(_lobby_manager.get_local_players().size(), 1, "Should have 1 local player")
	assert_eq(_lobby_manager.get_all_players().size(), 2, "Should have 2 total players, including local")

	p1.queue_free()
	await wait_process_frames(2)

	assert_eq(_lobby_manager.get_local_players().size(), 1, "Should have 1 local player")
	assert_eq(_lobby_manager.get_all_players().size(), 1, "Should have 1 total players, including local")

	p2.queue_free()
	await wait_process_frames(2)

	assert_eq(_lobby_manager.get_local_players().size(), 0, "Should have 0 local players")
	assert_eq(_lobby_manager.get_all_players().size(), 0, "Should have 0 total players")

func test_multiple_local_players_on_same_peer():
	assert_eq(_lobby_manager.get_local_players().size(), 0, "Initial count should be 0")

	# Add local player 1 (device 0)
	var lp1 = _add_player(1, 0)
	# Add local player 2 (device 1)
	var lp2 = _add_player(1, 1)

	assert_eq(_lobby_manager.get_local_players().size(), 2, "Should have 2 local players")
	assert_eq(_lobby_manager.get_local_player(0), lp1, "Device 0 should be lp1")
	assert_eq(_lobby_manager.get_local_player(1), lp2, "Device 1 should be lp2")

	# Removal of one
	lp1.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_local_players().size(), 1, "Should have 1 local player after removing device 0")
	assert_null(_lobby_manager.get_local_player(0), "Device 0 should be null")
	assert_eq(_lobby_manager.get_local_player(1), lp2, "Device 1 should still be lp2")

	# Removal of other
	lp2.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_local_players().size(), 0, "Should have 0 local players")

func test_get_all_players_returns_an_array():
	assert_eq(_lobby_manager.get_all_players().size(), 0, "Should have 0 total players")

	# Add local player 1 (device 0)
	var lp1 = _add_player(1, 0)
	# Add local player 2 (device 1)
	var lp2 = _add_player(1, 1)

	assert_eq(_lobby_manager.get_all_players().size(), 2, "Should have 2 total players")
	assert_eq(_lobby_manager.get_all_players()[0], lp1, "First player should be lp1")
	assert_eq(_lobby_manager.get_all_players()[1], lp2, "Second player should be lp2")

	# Removal of one
	lp1.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_all_players().size(), 1, "Should have 1 total player after removing device 0")
	assert_eq(_lobby_manager.get_all_players()[0], lp2, "First player should be lp2")

	# Removal of other
	lp2.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_all_players().size(), 0, "Should have 0 total players")

func test_get_all_player_peer_ids_returns_integer_array():
	assert_eq(_lobby_manager.get_all_player_peer_ids().size(), 0, "Should have 0 total peer ids")

	# Add local player 1 (device 0)
	var lp1 = _add_player(1, 0)
	# Add local player 2 (device 1)
	var lp2 = _add_player(1, 1)
	# Add remote player 3 (peer_id 2)
	var rp1 = _add_player(2, 0)

	assert_eq(_lobby_manager.get_all_player_peer_ids(), [1, 2], "Should have peer ids 1 and 2")
	
	# Removal of one
	lp1.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_all_player_peer_ids(), [1, 2], "Should have peer ids 1 and 2")
	
	# Removal of other
	lp2.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_all_player_peer_ids(), [2], "Should have peer id 2")
	
	# Removal of remote
	rp1.queue_free()
	await wait_process_frames(2)
	assert_eq(_lobby_manager.get_all_player_peer_ids(), [], "Should have 0 total peer ids")

func test_emits_status_update_for_spawned_lobby_players(params = use_parameters(SPAWN_PARAMS)):
	var peer_id = params[0]
	var local_player_id = params[1]
	
	watch_signals(_lobby_manager)
	
	# Manual node addition (simulates MultiplayerSpawner behavior)
	var p_node = _add_player(peer_id, local_player_id)

	# updating the player emits the player_status_update signal
	assert_signal_not_emitted(_lobby_manager.player_status_update)
	p_node.status = LobbyPlayer.Status.SYNCED
	assert_signal_emitted_with_parameters(_lobby_manager.player_status_update, [peer_id, local_player_id, LobbyPlayer.Status.SYNCED])

	p_node.free()

func test_emits_player_joined_and_left(params = use_parameters(SPAWN_PARAMS)):
	var peer_id = params[0]
	var local_player_id = params[1]
	
	watch_signals(_lobby_manager)
	
	# player_joined
	assert_signal_not_emitted(_lobby_manager.player_joined)
	
	# Manual node addition (simulates MultiplayerSpawner behavior)
	var p_node = _add_player(peer_id, local_player_id)
	assert_signal_emitted_with_parameters(_lobby_manager.player_joined, [peer_id, local_player_id])
	
	# player_left
	assert_signal_not_emitted(_lobby_manager.player_left)
	_lobby_manager._lobby_players_container.remove_child(p_node)
	assert_signal_emitted_with_parameters(_lobby_manager.player_left, [peer_id, local_player_id])

	# cleanup
	p_node.free()

func test_spawn_and_remove_lobby_player_on_peer_connection():
	# Test _on_peer_connected
	var peer_id = 456

	assert_null(_lobby_manager.get_player(peer_id), "Player node should not exist before peer is connected")
	_lobby_manager._on_peer_connected(peer_id)
	var p = _lobby_manager.get_player(peer_id)
	assert_not_null(p, "Player node should be spawned for connected peer")

	# Test _on_peer_disconnected
	_lobby_manager._on_peer_disconnected(peer_id)
	await wait_process_frames(2) # queue_free
	assert_null(_lobby_manager.get_player(peer_id), "Player node should be removed for disconnected peer")

func test_update_player_status_updates_found_local_players():
	# Base player (It's a mocked player)
	var new_player = _add_player(1, 0)

	# Update the status on a guest player (fails silently)
	_lobby_manager.update_player_status(LobbyPlayer.Status.SYNCED, 1)
	assert_not_called(new_player.set_status)

	# Update status on the host player (succeeds)
	_lobby_manager.update_player_status(LobbyPlayer.Status.SYNCED, 0)
	assert_called(new_player.set_status.bind(LobbyPlayer.Status.SYNCED))

	# Now that it exists, the status update should go through
	var second_player = _add_player(1, 1)
	_lobby_manager.update_player_status(LobbyPlayer.Status.SYNCED, 1)
	assert_called(second_player.set_status.bind(LobbyPlayer.Status.SYNCED))

func test_update_all_local_player_status_updates_all_found_local_players():
	var p1 = _add_player(1, 0)
	var p2 = _add_player(1, 1)
	var p3 = _add_player(2, 0) # Remote player

	_lobby_manager.update_all_local_player_status(LobbyPlayer.Status.SYNCED)
	# Both should have been called
	assert_called(p1.set_status.bind(LobbyPlayer.Status.SYNCED))
	assert_called(p2.set_status.bind(LobbyPlayer.Status.SYNCED))
	# Third should _not_ have been called
	assert_not_called(p3.set_status)

func test_update_player_name_only_updates_host():
	var p1 = _add_player(1, 0)
	var p2 = _add_player(1, 1)
	var p3 = _add_player(2, 0) # Remote player

	_lobby_manager.update_player_name("New Name")
	# Host player name delegation is tested on LobbyPlayer
	assert_called(p1.update_player_name.bind("New Name"))
	assert_not_called(p2.update_player_name)
	assert_not_called(p3.update_player_name)

#endregion

#region Scene Management

func test_scene_transition_on_map_change():
	var test_path = "res://scenes/maps/TestMap.tscn"
	
	# Trigger map change
	_lobby_manager.current_lobby.active_scene_path = test_path
	
	# Assert that SceneManager.start_transition_to was called with the correct path
	assert_called(_mock_scene_manager.start_transition_to.bind(test_path))

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

#endregion

func _add_player(peer_id: int, local_player_id: int) -> LobbyPlayer:
	var params := [peer_id, local_player_id]
	var lobby_player = double(LobbyPlayer).new()
	lobby_player.peer_id = peer_id
	lobby_player.local_player_id = local_player_id
	_lobby_manager._lobby_players_container.add_child(lobby_player)
	return lobby_player
