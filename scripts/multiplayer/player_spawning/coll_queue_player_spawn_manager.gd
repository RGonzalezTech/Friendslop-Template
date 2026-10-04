class_name CollQueuePlayerSpawnManager
extends BasePlayerSpawnManager

## This player spawn manager uses a queue to ensure that players are spawned in a collision-safe manner.
## You must provide the [member spawn_points] property, which should be a parent node consisting of either
## [Area2D] or [Area3D] nodes. The spawn manager will use the `has_overlapping_bodies()` method to check for collisions.

## The parent node for the spawn points consisting of either [Area2D] or [Area3D] nodes.
@export var spawn_points: Node

## Queue of [peer_id, local_player_id] tuples waiting to be spawned
var _spawn_queue: Array[Array] = []

## Timer to retry spawning remaining players
var _retry_timer: Timer

func _enter_tree() -> void:
	super ()
	_setup_retry_timer()

func _ready() -> void:
	super ()
	assert(spawn_points != null, "Spawn points must be set")
	assert(spawn_points.get_child_count() > 0, "No spawn points available")

## [OVERRIDE] Rather than instantly spawn players, we add them to the queue to try to spawn every N seconds
func _on_player_ready_for_gameplay(peer_id: int, local_player_id: int) -> void:
	var players_for_peer = _spawned_players.get(peer_id, {})
	if players_for_peer.has(local_player_id):
		return

	# Check if already queued
	for entry in _spawn_queue:
		if entry[0] == peer_id and entry[1] == local_player_id:
			return

	_spawn_queue.append([peer_id, local_player_id])
	_retry_timer.start()

## A player has left the lobby.
func _on_player_left(peer_id: int, local_player_id: int) -> void:
	# Do the usual
	super (peer_id, local_player_id)

	# And also, remove from the spawn_queue if they haven't spawned yet
	var index = -1
	for i in range(_spawn_queue.size()):
		if _spawn_queue[i][0] == peer_id and _spawn_queue[i][1] == local_player_id:
			index = i
			break

	if index != -1:
		_spawn_queue.remove_at(index)
		if _spawn_queue.is_empty():
			_retry_timer.stop()

# Every N seconds, try to spawn any remaining players
func _try_spawn() -> void:
	# No players to spawn
	if _spawn_queue.is_empty():
		_retry_timer.stop()
		return
	
	# We try to utilize all available spawn points in a single frame
	var available_spawn_points = spawn_points.get_child_count()
	for i in range(available_spawn_points):
		# Stop if no more players to spawn
		if _spawn_queue.is_empty():
			break

		# Must be [Area2D] or [Area3D]
		var this_spawn_point = spawn_points.get_child(i)
		assert(this_spawn_point.has_method("has_overlapping_bodies"), "Spawn point must be an Area2D or Area3D")

		# If this spawn point is already occupied, skip it
		if this_spawn_point.has_overlapping_bodies():
			continue
		
		# Else: Spawn next player in queue here
		var entry = _spawn_queue.pop_front()
		var params = _make_spawn_params(entry[0], entry[1], this_spawn_point)
		_validate_params(params)
		handshake_spawner.spawn(player_spawner_label, params)

	# If the queue is now empty, stop the timer
	if _spawn_queue.is_empty():
		_retry_timer.stop()

func _make_spawn_params(peer_id: int, local_player_id: int, spawn_point: Node) -> Dictionary:
	return {
		"peer_id": peer_id,
		"local_player_id": local_player_id,
		"position": spawn_point.position,
	}

# Prepares the retry timer
func _setup_retry_timer() -> void:
	# Setup retry timer
	_retry_timer = Timer.new()
	_retry_timer.wait_time = 0.2
	_retry_timer.one_shot = false
	_retry_timer.autostart = false
	_retry_timer.timeout.connect(_try_spawn)

	add_child(_retry_timer)
