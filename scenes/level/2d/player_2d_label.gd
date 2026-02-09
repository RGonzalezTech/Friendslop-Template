class_name Player2DLabel
extends Label

## This label will follow the _player with a smooth lerp.
## It detaches from the _player when ready to prevent rotation issues.

## The smoothing factor for the label.
@export_range(0.0, 1.0) var smoothing: float = 0.1

## The _offset of the label from the _player.
var _offset: Vector2 = Vector2.ZERO

## The _player this label is attached to.
var _player: Player2D

func _ready() -> void:
    _player = get_parent() as Player2D
    assert(_player is Player2D, "Player2DLabel must have a Player2D parent")
    _offset = (global_position - _player.global_position)
    name = "Player2DLabel_" + str(_player.peer_id)
    _update_text()
    # Call deferred because we can't reparent during scene tree initialization
    self.reparent.call_deferred(get_tree().root)

func _update_text() -> void:
    var lobby_player := LobbyManager.get_player(_player.peer_id)
    if lobby_player:
        text = lobby_player.player_name
    else:
        text = "Player " + str(_player.peer_id)

# The position needs to lerp to the _player position + _offset
func _process(_delta: float) -> void:
    if not is_instance_valid(_player):
        queue_free()
        return

    var target_position: Vector2 = _player.global_position + _offset
    global_position = global_position.lerp(target_position, smoothing)