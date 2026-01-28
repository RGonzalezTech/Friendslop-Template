extends HBoxContainer

## A UI component representing a single player in the lobby list.
## Automatically updates its display when the associated [LobbyPlayer] node changes.

@onready var name_label: Label = $NameLabel
@onready var status_label: Label = $StatusLabel

var _player_node: LobbyPlayer

## Binds this UI item to a [LobbyPlayer] node and starts listening for property changes.
func listen_for_updates(player_node: LobbyPlayer) -> void:
	if _player_node and _player_node.info_changed.is_connected(refresh):
		_player_node.info_changed.disconnect(refresh)
		
	_player_node = player_node
	
	if _player_node:
		_player_node.info_changed.connect(refresh)
	
	refresh()

## Forces a manual refresh of the UI labels based on the current player state.
func refresh() -> void:
	if not _player_node: return
	
	# Needs the labels
	if (not name_label or not status_label):
		return
	
	name_label.text = _player_node.player_name
	status_label.text = "[Ready]" if _player_node.is_ready else "[Not Ready]"
	
	if _player_node.is_ready:
		status_label.modulate = Color.GREEN
	else:
		status_label.modulate = Color.GRAY
