class_name HandshakeSynchronizer
extends MultiplayerSynchronizer

## This node is responsible for the sync heartbeat for a given [MultiplayerSynchronizer]

var _handshake: HandshakeRetryTimer

func _enter_tree() -> void:
	if not replication_config:
		replication_config = SceneReplicationConfig.new()

	if multiplayer.is_server():
		public_visibility = false
	else:
		_handshake = HandshakeRetryTimer.new()
		_handshake.sync_requested.connect(_on_sync_requested)
		add_child(_handshake)

func _on_sync_requested() -> void:
	# Always request sync from the server
	_rpc_client_request_sync.rpc_id(1)

# Client -> Server: I'm ready to play!
# Lets the server know that the client is ready to sync this node.
@rpc("any_peer", "call_local", "reliable")
func _rpc_client_request_sync() -> void:
	if not multiplayer.is_server():
		return

	# Start sending sync data to the client
	var sender_id = multiplayer.get_remote_sender_id()
	set_visibility_for(sender_id, true)
	_rpc_server_ack_sync.rpc_id(sender_id)

# Server -> Client: I've added your permissions
# Lets the client know that they can stop requesting sync.
@rpc("authority", "call_local", "reliable")
func _rpc_server_ack_sync() -> void:
	if _handshake:
		_handshake.ack()
