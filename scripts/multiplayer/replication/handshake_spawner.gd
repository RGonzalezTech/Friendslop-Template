class_name HandshakeSpawner
extends Node

## This node is responsible for handling entity spawning in a multiplayer environment.
## It uses a handshake pattern to ensure that spawn packets are only sent when the client is ready to receive them.

## Emitted when an entity is spawned locally.
signal spawned(node: Node, request: SpawnRequest)
## Emitted when an entity is despawned locally.
signal despawned(s_id: String)

## Maps Labels (e.g., "enemy_grunt") to SpawnableResource resources.
@export var spawnables: Dictionary[String, SpawnableResource] = {}

## The node that will contain all spawned entities
@export var spawn_path: NodePath
var _spawn_node: Node

# Maps spawned entity IDs to their metadata
var _spawned: Dictionary[String, SpawnRequest] = {}

var _handshake: HandshakeRetryTimer

#region Initialization

func _enter_tree() -> void:
	assert(spawn_path, "HandshakeSpawner must have a spawn_path")

func _ready() -> void:
	_spawn_node = get_node(spawn_path)

	if not multiplayer.is_server():
		_handshake = HandshakeRetryTimer.new()
		_handshake.sync_requested.connect(func(): _rpc_request_spawn_replay.rpc_id(1))
		add_child(_handshake)

#endregion

#region Server API

## Spawns an entity of the matching type, then
## sends the spawn packet to all peers.
func spawn(type: String, params: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var spawn_req = SpawnRequest.new(type, params)
	var spawn_req_dict = spawn_req.to_dict()

	# Spawn locally
	_rpc_spawn(spawn_req_dict)
	# Wait a frame to ensure the node is added to the tree
	await get_tree().process_frame
	# Send to all peers
	_rpc_spawn.rpc(spawn_req_dict)


## Despawns an entity of the matching ID, then
## sends the despawn_id packet to all peers.
func despawn_id(s_id: String) -> void:
	if not multiplayer:
		return

	var peer = multiplayer.multiplayer_peer
	if not peer:
		return
	
	const CONNECTED = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED

	if peer.get_connection_status() != CONNECTED:
		return

	if not multiplayer.is_server():
		return

	if not _spawned.has(s_id):
		push_warning("HandshakeSpawner: Attempted to despawn_id unknown s_id: %s" % s_id)
		return

	# Despawn locally
	_rpc_despawn(s_id)
	# Send to all peers
	_rpc_despawn.rpc(s_id)


## Helper to despawn_id an entity node directly.
func despawn_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var s_id = node.get_meta("s_id", "")
	if s_id != "":
		despawn_id(s_id)
	else:
		push_warning("HandshakeSpawner: Attempted to despawn_id node without s_id metadata: %s" % node.name)

#endregion

#region Server RPCs

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_spawn_replay() -> void:
	# Client -> Server: Request spawn replay to catch-up
	# We want to iterate through our _spawned and send them spawn packets
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()
	
	# Replay history for this specific client
	for spawn_id in _spawned:
		var this_request: SpawnRequest = _spawned[spawn_id]
		
		# This allows the asset to grab the new position, health, etc.
		var spawned_node = this_request.node
		if is_instance_valid(spawned_node) and spawned_node.has_method("get_spawn_params"):
			this_request.params = spawned_node.get_spawn_params()
		
		var packet = this_request.to_dict()
		_rpc_spawn.rpc_id(sender_id, packet)
	
	_rpc_ack_spawn_replay.rpc_id(sender_id)

#endregion

#region Client RPCs

@rpc("authority", "call_local", "reliable")
func _rpc_ack_spawn_replay() -> void:
	# Server -> Client: Acknowledge the spawn replay request
	if _handshake:
		_handshake.ack()


@rpc("authority", "call_local", "reliable")
func _rpc_spawn(packet: Dictionary) -> void:
	# Server -> Client: Spawn the entity
	var spawn_req = SpawnRequest.from_dict(packet)
	if _spawned.has(spawn_req.spawn_id):
		# We already have this entity, ignore it
		return
	
	# Get the "SpawnableResource" for this type
	var spawnable: SpawnableResource = spawnables.get(spawn_req.type)
	assert(spawnable, "Invalid spawn type: %s" % spawn_req.type)

	var new_node = spawnable.spawn(spawn_req.params)
	if not new_node:
		push_warning("HandshakeSpawner: SpawnableResource %s returned null for s_id %s" % [spawn_req.type, spawn_req.spawn_id])
		return

	# Track metadata for easy lookup
	new_node.name = spawn_req.spawn_id
	new_node.set_meta("s_id", spawn_req.spawn_id)
	# Ensure memory is cleaned up if the node is freed via other means
	new_node.tree_exited.connect(func(): _spawned.erase(spawn_req.spawn_id))

	spawn_req.node = new_node
	_spawned[spawn_req.spawn_id] = spawn_req
	_spawn_node.add_child(new_node)
	spawned.emit(new_node, spawn_req)


@rpc("authority", "call_local", "reliable")
func _rpc_despawn(s_id: String) -> void:
	# Server -> Client: Despawn the entity
	if not _spawned.has(s_id):
		return

	var spawn_req = _spawned[s_id]
	var node = spawn_req.node
	
	# Clean up from dictionary first to prevent re-entry
	_spawned.erase(s_id)

	if is_instance_valid(node):
		var spawnable: SpawnableResource = spawnables.get(spawn_req.type)
		assert(spawnable, "Invalid spawn type: %s" % spawn_req.type)
		spawnable.teardown(node)

	despawned.emit(s_id)

#endregion
