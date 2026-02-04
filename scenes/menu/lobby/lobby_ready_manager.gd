class_name ReadyManager
extends Node

## Maps a peer_id to their ready status (true or false)
@export var player_ready_states: Dictionary[int, bool] = {}:
	set(value):
		player_ready_states = value
		_update_all_ready_status.call_deferred()

## Maps peer_id to the player row node (for updating Ready status)
var _spawned_rows: Dictionary[int, LobbyPlayerRow] = {}
## Maps spawn_id to peer_id (for cleaning up rows)
var _spawned_sids: Dictionary[String, int] = {}

#region UI Updates

func _update_all_ready_status() -> void:
	for peer_id in _spawned_rows.keys():
		var is_ready = player_ready_states.get(peer_id)
		var this_row = _spawned_rows[peer_id]
		if not this_row:
			continue
		assert(this_row.has_method("set_ready_status"), "Player row does not have set_ready_status method")
		this_row.set_ready_status(is_ready)

## Refreshes the ready states of all players via MultiplayerSynchronizer
## this is a bit of a hack, but it works to trigger the sync of the ready states
func _trigger_ready_updates() -> void:
	player_ready_states = player_ready_states

#endregion

#region Spawner Callbacks

## Called when a player row is spawned
func _on_handshake_spawner_spawned(node: LobbyPlayerRow, request: SpawnRequest) -> void:
	var peer_id = request.params.get("peer_id")
	assert(peer_id, "Spawn request does not contain peer_id")

	# For updating ready status
	_spawned_rows[peer_id] = node
	# For cleaning up rows
	_spawned_sids[request.spawn_id] = peer_id
	player_ready_states[peer_id] = false
	_trigger_ready_updates()

## Called when a player row is despawned
func _on_handshake_spawner_despawned(s_id: String) -> void:
	var peer_id = _spawned_sids.get(s_id)
	if not peer_id:
		return
	_spawned_sids.erase(s_id)
	_spawned_rows.erase(peer_id)
	player_ready_states.erase(peer_id)
	_trigger_ready_updates()

#endregion

#region Player Ready Toggle

func _on_ready_btn_pressed() -> void:
	_request_ready_toggle.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _request_ready_toggle() -> void:
	if not multiplayer.is_server():
		return

	var this_player = multiplayer.get_remote_sender_id()
	var new_ready = !player_ready_states.get(this_player, false)
	player_ready_states[this_player] = new_ready
	_trigger_ready_updates()

#endregion
