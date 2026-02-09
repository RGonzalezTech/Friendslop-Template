class_name Player2D
extends CharacterBody2D

## The speed of the player.
@export var speed: float = 300.0

## The peer ID of the player.
@export var peer_id: int = -1:
	set(value):
		peer_id = value

## The current look direction of the player, synchronized across peers.
@export var look_direction: Vector2 = Vector2.RIGHT

## The MultiplayerSynchronizer for this player.
@onready var player_sync: HandshakeSynchronizer = $Player2DSync

## The input action router for this player.
@onready var action_router: GameActionRouter2D = $Player2DActions

var input: Vector2 = Vector2.ZERO

func get_spawn_params() -> Dictionary:
	return {
		"peer_id": peer_id,
		"position": global_position,
	}

# Add our local camera and input controls 
func _add_local_control() -> void:
	var local_camera = $Player2DCamera
	assert(local_camera is Player2DCamera, "Player2D must have a Player2DCamera")
	local_camera.action_router = action_router
	local_camera.enabled = true
	local_camera.make_current()

func _ready() -> void:
	assert(peer_id != -1, "Player2D must have a peer_id")
	assert(player_sync is HandshakeSynchronizer, "Player2D must have a HandshakeSynchronizer")
	if peer_id == multiplayer.get_unique_id():
		_add_local_control()

func _physics_process(_delta: float) -> void:
	var peer = multiplayer.multiplayer_peer
	const CONNECTED = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED
	var has_connection = peer and peer.get_connection_status() == CONNECTED

	if has_connection and peer_id == multiplayer.get_unique_id():
		# Our player, process inputs
		var horizontal = action_router.get_axis("move_left", "move_right")
		var vertical = action_router.get_axis("move_up", "move_down")
		var new_input = Vector2(horizontal, vertical)
		_rpc_set_input.rpc_id(1, new_input)
		
		# Process look direction
		var new_look_direction = action_router.get_look_direction()
		if new_look_direction != Vector2.ZERO:
			_rpc_set_look_direction.rpc_id(1, new_look_direction)
	
	velocity = input * speed
	move_and_slide()
	
	# Apply rotation based on look direction
	if look_direction != Vector2.ZERO:
		rotation = look_direction.angle()

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_input(new_input: Vector2) -> void:
	if not multiplayer.is_server():
		return
	
	# Only the node owner can set the property
	if not peer_id == multiplayer.get_remote_sender_id():
		return

	input = new_input

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_look_direction(new_look_direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	
	# Only the node owner can set the property
	if not peer_id == multiplayer.get_remote_sender_id():
		return

	look_direction = new_look_direction
