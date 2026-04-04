extends BaseNetworkGutTest

#region init

func before_all() -> void:
    super ()
    # Set up as a network server
    setup_server()

    # Speed up the retry timer for this test
    Engine.time_scale = 2

func after_all() -> void:
    super ()
    Engine.time_scale = 1

var mock_network_root: NetworkLevelRoot
var mock_handshake_spawner: HandshakeSpawner

class MockSpawnPoint:
    extends Node2D

    ## Mock the output by setting [member can_spawn]

    var can_spawn: bool = false

    # Mocked output
    func has_overlapping_bodies() -> bool:
        # If we can spawn, then nothing is blocking us
        return !can_spawn

var spawn_points: Node2D
var _spawn_points_arr: Array[MockSpawnPoint]

var spawn_manager: CollQueuePlayerSpawnManager

func before_each() -> void:
    mock_network_root = double(NetworkLevelRoot).new()
    _server_node.add_child(mock_network_root)

    mock_handshake_spawner = double(HandshakeSpawner).new()
    _server_node.add_child(mock_handshake_spawner)

    spawn_points = Node2D.new()
    _server_node.add_child(spawn_points)

    # 3 Spawn Points
    _spawn_points_arr.clear()
    for i in range(3):
        var new_spawn = MockSpawnPoint.new()
        new_spawn.name = "Spawn %d" % [i]
        # Linear Scaling Position
        new_spawn.position = Vector2(20, 20) * i
        _spawn_points_arr.append(new_spawn)
        spawn_points.add_child(new_spawn)
    
    spawn_manager = CollQueuePlayerSpawnManager.new()
    spawn_manager.spawn_points = spawn_points
    spawn_manager.network_level_root = mock_network_root
    spawn_manager.handshake_spawner = mock_handshake_spawner
    _server_node.add_child(spawn_manager)

func after_each() -> void:
    mock_network_root.free()
    mock_handshake_spawner.free()
    spawn_manager.free()

#endregion

func test_sets_up_timer() -> void:
    assert_true(spawn_manager._retry_timer is Timer, "Must spawn timer when added")

func test_timer_isnt_running() -> void:
    assert_true(spawn_manager._retry_timer.is_stopped(), "Timer must not be running yet")

func test_spawn_when_point_is_free() -> void:
    # Set point 0 to be free
    _spawn_points_arr[0].can_spawn = true
    
    var peer_id = 42
    var local_player_id = 0
    mock_network_root.player_ready_for_gameplay.emit(peer_id, local_player_id)
    assert_eq(spawn_manager._spawn_queue.size(), 1, "Must have 1 in queue")
    assert_eq(spawn_manager._spawn_queue[0], [peer_id, local_player_id], "Queue entry should be a [peer_id, local_player_id] tuple")
    
    # Needs to wait a frame for call_deferred
    await wait_seconds(0.25)

    # Should've tried to spawn at pos 0
    assert_called(mock_handshake_spawner.spawn.bind("player", {
        "peer_id": peer_id,
        "local_player_id": local_player_id,
        "position": _spawn_points_arr[0].position
    }))
    assert_eq(spawn_manager._spawn_queue.size(), 0, "Queue should be empty")

func test_queue_when_points_are_occupied() -> void:
    # All points occupied by default
    var peer_id = 42
    var local_player_id = 0
    mock_network_root.player_ready_for_gameplay.emit(peer_id, local_player_id)
    
    # Needs to wait a second for call_deferred
    await wait_seconds(0.25)
    
    assert_not_called(mock_handshake_spawner.spawn)
    assert_eq(spawn_manager._spawn_queue, [[peer_id, local_player_id]], "Spawn queue should have [peer_id, local_player_id] tuple")
    assert_false(spawn_manager._retry_timer.is_stopped(), "Timer should be running")

func test_multiple_spawns_across_available_points() -> void:
    # 3 points free initially
    _spawn_points_arr[0].can_spawn = true
    _spawn_points_arr[1].can_spawn = true
    _spawn_points_arr[2].can_spawn = true

    # Simulate Peer 1 connecting
    mock_network_root.player_ready_for_gameplay.emit(1, 0)
    await wait_seconds(0.25)
    
    # Peer 1 should spawn at point 0
    assert_called_count(mock_handshake_spawner.spawn, 1)
    assert_called(mock_handshake_spawner.spawn.bind("player", {
        "peer_id": 1,
        "local_player_id": 0,
        "position": _spawn_points_arr[0].position
    }))
    
    # Simulate body overlap on point 0 (mocking physics update)
    _spawn_points_arr[0].can_spawn = false

    # Simulate Peer 2 connecting
    mock_network_root.player_ready_for_gameplay.emit(2, 0)
    await wait_seconds(0.25)

    # Peer 2 should spawn at point 1
    assert_called_count(mock_handshake_spawner.spawn, 2)
    assert_called(mock_handshake_spawner.spawn.bind("player", {
        "peer_id": 2,
        "local_player_id": 0,
        "position": _spawn_points_arr[1].position
    }))
    
    # Simulate body overlap on point 1
    _spawn_points_arr[1].can_spawn = false

    # Simulate Peer 3 connecting
    mock_network_root.player_ready_for_gameplay.emit(3, 0)
    await wait_seconds(0.25)

    # Peer 3 should spawn at point 2
    assert_called_count(mock_handshake_spawner.spawn, 3)
    assert_called(mock_handshake_spawner.spawn.bind("player", {
        "peer_id": 3,
        "local_player_id": 0,
        "position": _spawn_points_arr[2].position
    }))
    
    # Simulate body overlap on point 2
    _spawn_points_arr[2].can_spawn = false

    # Simulate Peer 4 connecting (queue test)
    mock_network_root.player_ready_for_gameplay.emit(4, 0)
    await wait_seconds(0.25)

    # Peer 4 should not have spawned and should be in the queue
    assert_called_count(mock_handshake_spawner.spawn, 3)
    assert_eq(spawn_manager._spawn_queue, [[4, 0]], "One player should remain in queue ([4, 0])")

func test_doesnt_queue_if_already_spawned_or_queued() -> void:
    # Mock spawned player (nested: peer 42 -> local_player 0 -> SpawnRequest)
    spawn_manager._spawned_players[42] = {0: SpawnRequest.new()}
    
    mock_network_root.player_ready_for_gameplay.emit(42, 0)
    assert_eq(spawn_manager._spawn_queue.size(), 0, "Should not queue if already spawned")
    
    # Remove from spawned, add to queue as tuple
    spawn_manager._spawned_players.erase(42)
    spawn_manager._spawn_queue.append([100, 0])
    
    mock_network_root.player_ready_for_gameplay.emit(100, 0)
    assert_eq(spawn_manager._spawn_queue.size(), 1, "Should not queue if already in queue")

func test_remove_from_queue_when_player_leaves() -> void:
    # 1. Trigger player ready for gameplay
    var peer_id = 42
    var local_player_id = 0
    mock_network_root.player_ready_for_gameplay.emit(peer_id, local_player_id)
    assert_eq(spawn_manager._spawn_queue.size(), 1, "Must have 1 in queue")
    assert_false(spawn_manager._retry_timer.is_stopped(), "Timer should be running")

    # 2. Trigger player leave
    LobbyManager.player_left.emit(peer_id, local_player_id)

    # 3. Verify player is removed from queue and timer is stopped
    assert_eq(spawn_manager._spawn_queue.size(), 0, "Queue should be empty")
    assert_true(spawn_manager._retry_timer.is_stopped(), "Timer should be stopped")
    
    # 4. Wait a few frames and verify player was NEVER spawned
    await wait_seconds(0.25)
    assert_not_called(mock_handshake_spawner.spawn)

## New: Two local players from the same peer are queued as separate entries
func test_two_local_players_same_peer_queued_independently() -> void:
    var peer_id = 10
    mock_network_root.player_ready_for_gameplay.emit(peer_id, 0)
    mock_network_root.player_ready_for_gameplay.emit(peer_id, 1)

    assert_eq(spawn_manager._spawn_queue.size(), 2, "Both local players should be queued")
    assert_eq(spawn_manager._spawn_queue[0], [peer_id, 0])
    assert_eq(spawn_manager._spawn_queue[1], [peer_id, 1])

## New: Leaving one local player doesn't remove the other from the queue
func test_only_correct_local_player_removed_from_queue() -> void:
    var peer_id = 20
    mock_network_root.player_ready_for_gameplay.emit(peer_id, 0)
    mock_network_root.player_ready_for_gameplay.emit(peer_id, 1)
    assert_eq(spawn_manager._spawn_queue.size(), 2)

    LobbyManager.player_left.emit(peer_id, 0)

    assert_eq(spawn_manager._spawn_queue.size(), 1, "Only the leaving local player should be removed")
    assert_eq(spawn_manager._spawn_queue[0], [peer_id, 1])
