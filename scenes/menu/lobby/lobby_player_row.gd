class_name LobbyPlayerRow
extends HBoxContainer

## A UI component representing a single player in the lobby list.
## Automatically updates its display when the associated [LobbyPlayer] node changes.

@export var peer_id: int = 0:
	set(value):
		if value == peer_id:
			return
		_disconnect_player()
		peer_id = value
		_connect_player.call_deferred()

@onready var name_label: Label = $NameLabel
@onready var ready_label: Label = $ReadyLabel
@onready var status_label: Label = $StatusLabel

var _player_node: LobbyPlayer

func _disconnect_player():
	if _player_node and _player_node.info_changed.is_connected(refresh):
		_player_node.info_changed.disconnect(refresh)

func _connect_player():
	_player_node = LobbyManager.get_player(peer_id)
	assert(_player_node, "Player node not found for peer_id: %d" % peer_id)
	_player_node.info_changed.connect(refresh)
	refresh()

## Forces a manual refresh of the UI labels based on the current player state.
func refresh() -> void:
	if not _player_node: return
	
	# Needs the labels
	if (not name_label or not ready_label or not status_label):
		return
	
	name_label.text = _player_node.player_name
	
	# Update Status Label
	var status_name = LobbyPlayer.Status.keys()[_player_node.status]
	status_label.text = "[%s]" % status_name.capitalize()
	status_label.modulate = Color.CYAN # Use a distinct color for technical status

## Update the "Ready" label to the given state.
func set_ready_status(is_ready: bool) -> void:
	if not ready_label: return
	
	ready_label.text = "[Ready]" if is_ready else "[Not Ready]"
	if is_ready:
		ready_label.modulate = Color.GREEN
	else:
		ready_label.modulate = Color.GRAY
