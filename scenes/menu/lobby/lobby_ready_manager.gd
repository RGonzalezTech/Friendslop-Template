class_name ReadyManager
extends Node

## Maps a peer_id to their ready status (true or false)
@export var player_ready_states: Dictionary[int, bool] = {}:
	set(value):
		player_ready_states = value
		_update_all_ready_status.call_deferred()

## Maps peer_id -> Array of LobbyPlayerRow (one per local player on that peer)
var _spawned_rows: Dictionary[int, Array] = {}
## Maps spawn_id -> LobbyPlayerRow (for targeted removal on despawn)
var _spawned_sids: Dictionary[String, LobbyPlayerRow] = {}

#region UI Updates

func _update_all_ready_status() -> void:
	for peer_id in _spawned_rows.keys():
		var is_ready = player_ready_states.get(peer_id, false)
		for row in _spawned_rows[peer_id]:
			if not row:
				continue
			assert(row.has_method("set_ready_status"), "Player row does not have set_ready_status method")
			row.set_ready_status(is_ready)

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

	# Track row by spawn_id for targeted cleanup
	_spawned_sids[request.spawn_id] = node

	# Add to the per-peer row array
	if not _spawned_rows.has(peer_id):
		_spawned_rows[peer_id] = []
		# Only initialize ready state on the first row for this peer,
		# so a guest joining doesn't reset a peer that's already ready.
		player_ready_states[peer_id] = false

	_spawned_rows[peer_id].append(node)
	_trigger_ready_updates()

## Called when a player row is despawned
func _on_handshake_spawner_despawned(s_id: String) -> void:
	var row: LobbyPlayerRow = _spawned_sids.get(s_id)
	if not row:
		return
	_spawned_sids.erase(s_id)

	var peer_id := row.peer_id
	if _spawned_rows.has(peer_id):
		_spawned_rows[peer_id].erase(row)
		if _spawned_rows[peer_id].is_empty():
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

