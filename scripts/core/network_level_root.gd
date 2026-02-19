class_name NetworkLevelRoot
extends Node

## Abstract node responsible for announcing ready players when loading
## into new scenes.

## Server-Side: Emitted when a player becomes ready to start gameplay.
signal player_ready_for_gameplay(peer_id: int)

## Reference to the ready status for convenience.
const SYNCED = LobbyPlayer.Status.SYNCED

func _enter_tree() -> void:
	LobbyManager.player_status_update.connect(_on_player_status_update)

func _ready() -> void:
	_mark_ready()
	_server_announce_ready_players()

## Helper function to mark the scene as loaded.
func _mark_ready() -> void:
	SceneManager.mark_scene_as_loaded(self)

## Server-Side: Announce all ready players.
func _server_announce_ready_players() -> void:
	if not multiplayer.is_server():
		return
	
	# Allow 1 frame for all players to be ready.
	await get_tree().process_frame
	
	for player in LobbyManager.get_all_players():
		if player.status != SYNCED:
			continue
		player_ready_for_gameplay.emit(player.peer_id)

## Server-Side: Handle player status updates.
func _on_player_status_update(peer_id: int, status: LobbyPlayer.Status) -> void:
	if not multiplayer.is_server():
		return

	if status != SYNCED:
		return

	player_ready_for_gameplay.emit(peer_id)
