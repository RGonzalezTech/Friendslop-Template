class_name LocalSeatCoordinator
extends RefCounted

## Compacts local co-op seats and reconciles them with [LobbyManagerCode].
##
## Never touches UI. Listens for [signal LobbyManagerCode.player_joined] and
## [signal LobbyManagerCode.reject_add_player] until all requested additions
## resolve, rolling back only rejected seats to seat 0.

## Emitted when the server rejects adding [param seat] with [param reason].
## All devices bound to [param seat] have already been moved back to seat 0.
signal seat_rejected(seat: int, reason: String)

## Emitted once all pending seat additions succeed (or when no additions were needed).
signal committed

var coop_manager: LocalCoopManagerCode
var lobby_manager: LobbyManagerCode

var _pending_adds: Array[int] = []
var _had_rejection: bool = false

func _init(
	p_coop_manager: LocalCoopManagerCode = LocalCoopManager,
	p_lobby_manager: LobbyManagerCode = LobbyManager
) -> void:
	coop_manager = p_coop_manager
	lobby_manager = p_lobby_manager

## Renumbers occupied seats contiguously starting at 0 while preserving seat order.
## Returns the resulting sorted array of occupied seat indices.
func compact_seats() -> Array[int]:
	var active_slots: Array[int] = coop_manager.get_active_slots()
	active_slots.sort()

	var compacted: Array[int] = []
	for new_seat in range(active_slots.size()):
		var old_seat: int = active_slots[new_seat]
		if old_seat != new_seat:
			for device_id in coop_manager.get_devices_for_player(old_seat):
				coop_manager.bind_device(device_id, new_seat)
		compacted.append(new_seat)
	return compacted

## Compacts seats, diffs against [method LobbyManagerCode.get_local_players],
## and sends add/remove requests to the lobby.
func commit() -> void:
	cancel()

	var desired_seats: Array[int] = compact_seats()
	var existing_players: Dictionary = lobby_manager.get_local_players()

	var to_add: Array[int] = []
	for seat in desired_seats:
		if seat != LocalCoopManagerCode.PRIMARY_SLOT and not existing_players.has(seat):
			to_add.append(seat)

	var to_remove: Array[int] = []
	for existing_key in existing_players.keys():
		var seat: int = int(existing_key)
		if seat != LocalCoopManagerCode.PRIMARY_SLOT and not (seat in desired_seats):
			to_remove.append(seat)

	for seat in to_remove:
		lobby_manager.remove_local_player(seat)

	if to_add.is_empty():
		committed.emit()
		return

	_pending_adds = to_add.duplicate()
	_had_rejection = false
	_subscribe_lobby()

	for seat in to_add:
		lobby_manager.add_local_player(seat)

## Aborts tracking any in-flight add requests and disconnects lobby signals.
func cancel() -> void:
	_pending_adds.clear()
	_had_rejection = false
	_unsubscribe_lobby()

func _subscribe_lobby() -> void:
	_unsubscribe_lobby()
	if not is_instance_valid(lobby_manager):
		return
	lobby_manager.player_joined.connect(_on_player_joined)
	lobby_manager.reject_add_player.connect(_on_reject_add_player)

func _unsubscribe_lobby() -> void:
	if not is_instance_valid(lobby_manager):
		return
	if lobby_manager.player_joined.is_connected(_on_player_joined):
		lobby_manager.player_joined.disconnect(_on_player_joined)
	if lobby_manager.reject_add_player.is_connected(_on_reject_add_player):
		lobby_manager.reject_add_player.disconnect(_on_reject_add_player)

func _on_player_joined(peer_id: int, local_player_id: int) -> void:
	if not _is_local_peer(peer_id):
		return
	if not (local_player_id in _pending_adds):
		return
	_pending_adds.erase(local_player_id)
	_check_finished()

func _on_reject_add_player(local_player_id: int, reason: String) -> void:
	if not (local_player_id in _pending_adds):
		return
	_pending_adds.erase(local_player_id)
	_had_rejection = true

	for device_id in coop_manager.get_devices_for_player(local_player_id):
		coop_manager.bind_device(device_id, LocalCoopManagerCode.PRIMARY_SLOT)

	seat_rejected.emit(local_player_id, reason)
	_check_finished()

func _check_finished() -> void:
	if not _pending_adds.is_empty():
		return
	_unsubscribe_lobby()
	if not _had_rejection:
		committed.emit()

func _is_local_peer(peer_id: int) -> bool:
	if not is_instance_valid(lobby_manager):
		return false
	var mp: MultiplayerAPI = lobby_manager.multiplayer if lobby_manager.is_inside_tree() else null
	if mp == null or mp.multiplayer_peer == null:
		return false
	if mp.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return peer_id == mp.get_unique_id()
