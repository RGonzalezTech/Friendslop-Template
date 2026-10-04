extends BaseNetworkGutTest

var network_root: NetworkLevelRoot

# We want to setup the network level root on the server-side
func before_each():
    network_root = NetworkLevelRoot.new()
    watch_signals(network_root)
    setup_server()

func after_each():
    teardown_server()
    LobbyManager.reset_lobby()
    if network_root:
        network_root.free()

#region Player Ready for Gameplay Signal

func _add_test_player(peer_id: int, local_id: int = 0) -> LobbyPlayer:
    var player = double(LobbyPlayer).new()
    player.peer_id = peer_id
    player.local_player_id = local_id
    LobbyManager._lobby_players_container.add_child(player)
    return player

# This is a tough one cause I gotta figure out how to mock
# the player. I could just add them to the lobby managers player list.
func test_on_ready_announces_synced_players():
    # Shouldn't emit _yet_
    assert_signal_not_emitted(network_root.player_ready_for_gameplay)

    var p1 = _add_test_player(1, 0)
    var p2 = _add_test_player(2, 1)
    var _p3 = _add_test_player(3, 2)

    # Mark as ready
    p1.status = LobbyPlayer.Status.SYNCED
    p2.status = LobbyPlayer.Status.SYNCED

    # Still not emitted, not until _ready()
    assert_signal_not_emitted(network_root.player_ready_for_gameplay)

    _server_node.add_child(network_root)
    await wait_process_frames(2) # Wait for _ready() to be called

    # Should emit now
    assert_signal_emitted_with_parameters(network_root.player_ready_for_gameplay, [1, 0], 0)
    assert_signal_emitted_with_parameters(network_root.player_ready_for_gameplay, [2, 1], 1)

    # Only 2 players, not 3
    assert_signal_emit_count(network_root.player_ready_for_gameplay, 2)

    # There _should be_ 3 players total though
    assert_eq(LobbyManager.get_all_players().size(), 3)

func test_on_lobby_player_status_update_emits_player_ready_for_gameplay():
    var p1 = _add_test_player(1, 0)
    var _p2 = _add_test_player(2, 1)
    var _p3 = _add_test_player(3, 2)

    # Mark none as ready

    _server_node.add_child(network_root)
    await wait_process_frames(2) # Wait for _ready() to be called

    # Should still not emit
    assert_signal_not_emitted(network_root.player_ready_for_gameplay)

    # There _should be_ 3 players total though
    assert_eq(LobbyManager.get_all_players().size(), 3)

    # Now, we want to mark as ready and see it emit
    p1.status = LobbyPlayer.Status.SYNCED
    assert_signal_emitted_with_parameters(network_root.player_ready_for_gameplay, [1, 0])

#endregion