class_name Player3DLabel
extends Label3D

## This label floats above the 3D player with a smooth lerp.
## It detaches from the player on ready to prevent rotation issues.

## The smoothing factor for the label.
@export_range(0.0, 1.0) var smoothing: float = 0.1

## The offset of the label from the player.
var _offset: Vector3 = Vector3.ZERO

## The player this label is attached to.
var _player: Player3D

func _ready() -> void:
	_player = get_parent() as Player3D
	assert(_player is Player3D, "Player3DLabel must have a Player3D parent")
	_offset = global_position - _player.global_position
	name = "Player3DLabel_" + str(_player.peer_id)
	_update_text()
	# Reparent to world root so the label doesn't rotate with the player.
	self.reparent.call_deferred(get_tree().root)

func _update_text() -> void:
	var lobby_player := LobbyManager.get_player(_player.peer_id)
	if lobby_player:
		text = lobby_player.player_name
	else:
		text = "Player " + str(_player.peer_id)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return

	var target_position: Vector3 = _player.global_position + _offset
	global_position = global_position.lerp(target_position, smoothing)
