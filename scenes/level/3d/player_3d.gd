class_name Player3D
extends CharacterBody3D

## First-person 3D player controller.
## Uses the same multiplayer-authoritative pattern as Player2D:
## the owning client sends inputs via RPC, the server applies physics.

@export_group("Movement")
## Base walking speed (units/sec).
@export var base_speed: float = 7.0
## Sprint speed (units/sec).
@export var sprint_speed: float = 10.0
## Jump impulse velocity.
@export var jump_velocity: float = 4.5

@export_group("Multiplayer")
## The peer ID of the player.
@export var peer_id: int = -1:
	set(value):
		peer_id = value

## The current look rotation (x = pitch, y = yaw), synchronised across peers.
@export var look_rotation: Vector2 = Vector2.ZERO

## The MultiplayerSynchronizer for this player.
@onready var player_sync: HandshakeSynchronizer = $Player3DSync

## The input action router for this player.
@onready var action_router: GameActionRouter3D = $Player3DActions

## The head node that holds the camera (rotates on pitch axis).
@onready var head: Node3D = $Head

## The Camera3D node (child of Head).
@onready var camera: Camera3D = $Head/Camera3D

## Server-side input vector sent from the owning client.
var input: Vector2 = Vector2.ZERO

## Server-side flags sent from the owning client.
var _wants_jump: bool = false
var _wants_sprint: bool = false

func get_spawn_params() -> Dictionary:
	return {
		"peer_id": peer_id,
		"position": global_position,
	}

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	# Allow standalone testing: if no peer_id was set, assume local solo play.
	if peer_id == -1:
		push_warning("Player3D: No peer_id set. Assuming local solo play.")
		peer_id = multiplayer.get_unique_id()
	assert(player_sync is HandshakeSynchronizer, "Player3D must have a HandshakeSynchronizer")
	if peer_id == multiplayer.get_unique_id():
		_add_local_control()

## Enables camera and mouse capture for the local player.
func _add_local_control() -> void:
	assert(camera is Camera3D, "Player3D must have a Camera3D under Head")
	camera.current = true
	action_router.capture_mouse()

# -- Physics -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var peer = multiplayer.multiplayer_peer
	const CONNECTED = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED
	var has_connection = peer and peer.get_connection_status() == CONNECTED

	if has_connection and peer_id == multiplayer.get_unique_id():
		_send_inputs()

	_apply_look()
	_apply_movement(delta)

## Client-side: read from the action router and send to the server.
func _send_inputs() -> void:
	# Movement
	var move_dir := action_router.get_move_direction()
	_rpc_set_input.rpc_id(1, move_dir)

	# Look
	var look_input := action_router.get_look_input()
	if look_input != Vector2.ZERO:
		var new_look := look_rotation
		new_look.y -= look_input.x  # yaw (left/right)
		new_look.x -= look_input.y  # pitch (up/down)
		new_look.x = clamp(new_look.x, -action_router.get_max_pitch_rad(), action_router.get_max_pitch_rad())
		_rpc_set_look_rotation.rpc_id(1, new_look)
		# Apply immediately on the local client for snappy feel
		look_rotation = new_look
	action_router.consume_look_input()

	# Jump & sprint
	_rpc_set_flags.rpc_id(1, action_router.is_jump_just_pressed(), action_router.is_sprint_pressed())

## Applies look_rotation to the body (yaw) and head (pitch).
func _apply_look() -> void:
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

## Server-authoritative movement + gravity.
func _apply_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if _wants_jump and is_on_floor():
		velocity.y = jump_velocity
		_wants_jump = false

	# Speed
	var speed := sprint_speed if _wants_sprint else base_speed

	# Direction relative to body facing
	var move_dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if move_dir:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

# -- RPCs (Client -> Server) ---------------------------------------------------

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_input(new_input: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return
	input = new_input

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_look_rotation(new_look: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return
	look_rotation = new_look

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_flags(jump: bool, sprint: bool) -> void:
	if not multiplayer.is_server():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return
	if jump:
		_wants_jump = true
	_wants_sprint = sprint
