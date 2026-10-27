extends GutTest

const LocalCoopManager := preload("res://scripts/input/local_coop_manager.gd")

var _manager


func before_each() -> void:
	_manager = LocalCoopManager.new()
	add_child_autofree(_manager)
	# _ready() has already run: MKB is bound to slot 0, signals connected.


func after_each() -> void:
	pass  # _manager is autofreed.


# ============================================================================
# MKB Permanence
# ============================================================================

func test_mkb_is_permanently_slot_0() -> void:
	assert_eq(_manager.get_player_for_device(LocalCoopManager.MKB), 0,
		"MKB should be on slot 0 after _ready()")
	assert_eq(_manager.get_devices_for_player(0).size(), 1,
		"Slot 0 should have exactly 1 device (MKB)")
	assert_true(LocalCoopManager.MKB in _manager.get_devices_for_player(0),
		"MKB should be in slot 0's device list")


func test_bind_device_mkb_is_no_op() -> void:
	_manager.bind_device(LocalCoopManager.MKB, 3)
	assert_eq(_manager.get_player_for_device(LocalCoopManager.MKB), 0,
		"MKB should still be on slot 0 after bind attempt")
	assert_false(_manager._slot_to_devices.has(3),
		"Slot 3 should not exist (MKB bind was a no-op)")


func test_unbind_device_mkb_is_no_op() -> void:
	_manager.unbind_device(LocalCoopManager.MKB)
	assert_eq(_manager.get_player_for_device(LocalCoopManager.MKB), 0,
		"MKB should still be on slot 0 after unbind attempt")
	assert_eq(_manager.get_devices_for_player(0).size(), 1,
		"Slot 0 should still have 1 device (MKB)")


# ============================================================================
# bind_device
# ============================================================================

func test_bind_device_maps_gamepad_to_slot() -> void:
	_manager.bind_device(0, 1)
	assert_eq(_manager.get_player_for_device(0), 1,
		"Gamepad 0 should be on slot 1")
	assert_true(0 in _manager.get_devices_for_player(1),
		"Gamepad 0 should appear in slot 1's device list")


func test_bind_device_auto_unbinds_from_previous_slot() -> void:
	_manager.bind_device(0, 2)
	_manager.bind_device(0, 3)
	assert_eq(_manager.get_player_for_device(0), 3,
		"Gamepad 0 should be on slot 3 after rebind")
	assert_false(_manager._slot_to_devices.has(2),
		"Slot 2 should be empty after device moved away")


func test_bind_device_same_slot_is_no_op() -> void:
	_manager.bind_device(0, 1)
	watch_signals(_manager)
	_manager.bind_device(0, 1)
	assert_signal_not_emitted(_manager.device_bound,
		"device_bound should not fire when binding to the same slot")


func test_bind_device_multiple_devices_to_same_slot() -> void:
	_manager.bind_device(0, 1)
	_manager.bind_device(1, 1)
	assert_eq(_manager.get_devices_for_player(1).size(), 2,
		"Slot 1 should have 2 devices")
	assert_eq(_manager.get_player_for_device(0), 1)
	assert_eq(_manager.get_player_for_device(1), 1)


func test_bind_device_to_slot_0() -> void:
	# Slot 0 already has MKB. Bind a gamepad to it too.
	_manager.bind_device(0, 0)
	assert_eq(_manager.get_player_for_device(0), 0,
		"Gamepad 0 should be on slot 0")
	assert_eq(_manager.get_devices_for_player(0).size(), 2,
		"Slot 0 should have MKB + gamepad 0")
	assert_true(_manager.has_available_gamepad(),
		"has_available_gamepad should be true with MKB + gamepad on slot 0")


# ============================================================================
# unbind_device
# ============================================================================

func test_unbind_device_removes_mapping() -> void:
	_manager.bind_device(0, 1)
	_manager.unbind_device(0)
	assert_eq(_manager.get_player_for_device(0), 0,
		"Unbound device should default to slot 0")
	assert_false(_manager._slot_to_devices.has(1),
		"Slot 1 should be empty after unbind")


func test_unbind_device_unknown_is_no_op() -> void:
	watch_signals(_manager)
	_manager.unbind_device(99)
	assert_signal_not_emitted(_manager.device_unbound,
		"device_unbound should not fire for unknown device")


# ============================================================================
# Signals
# ============================================================================

func test_device_bound_signal_fires_on_bind() -> void:
	watch_signals(_manager)
	_manager.bind_device(0, 1)
	assert_signal_emitted_with_parameters(_manager.device_bound, [0, 1])


func test_device_unbound_signal_fires_on_explicit_unbind() -> void:
	_manager.bind_device(0, 1)
	watch_signals(_manager)
	_manager.unbind_device(0)
	assert_signal_emitted_with_parameters(_manager.device_unbound, [0, 1])


func test_device_bound_not_emitted_for_mkb() -> void:
	watch_signals(_manager)
	_manager.bind_device(LocalCoopManager.MKB, 3)
	assert_signal_not_emitted(_manager.device_bound)


func test_device_unbound_not_emitted_for_mkb() -> void:
	watch_signals(_manager)
	_manager.unbind_device(LocalCoopManager.MKB)
	assert_signal_not_emitted(_manager.device_unbound)


# ============================================================================
# Derived Properties
# ============================================================================

func test_active_players_counts_distinct_slots() -> void:
	assert_eq(_manager.get_active_players(), 1,
		"Only slot 0 (MKB) active initially")
	_manager.bind_device(0, 1)
	assert_eq(_manager.get_active_players(), 2,
		"Slots 0 and 1 active")
	_manager.bind_device(1, 1)
	assert_eq(_manager.get_active_players(), 2,
		"Still 2 slots — both gamepads on slot 1")
	_manager.bind_device(2, 3)
	assert_eq(_manager.get_active_players(), 3,
		"Slots 0, 1, 3 active")


func test_is_coop_false_with_one_player() -> void:
	assert_false(_manager.get_is_coop(),
		"Single player (MKB only) should not be co-op")


func test_is_coop_true_with_multiple_players() -> void:
	_manager.bind_device(0, 1)
	assert_true(_manager.get_is_coop(),
		"Two active slots should be co-op")


func test_get_active_slots_returns_sparse_slots() -> void:
	_manager.bind_device(0, 3)
	var slots = _manager.get_active_slots()
	assert_eq(slots.size(), 2, "Should have 2 active slots")
	assert_true(0 in slots, "Slot 0 should be active")
	assert_true(3 in slots, "Slot 3 should be active")


func test_has_available_gamepad_true_with_mkb_plus_gamepad() -> void:
	_manager.bind_device(0, 0)
	assert_true(_manager.has_available_gamepad(),
		"Slot 0 has MKB + gamepad → available gamepad")


func test_has_available_gamepad_false_with_only_mkb() -> void:
	assert_false(_manager.has_available_gamepad(),
		"Slot 0 has only MKB → no available gamepad")


func test_has_available_gamepad_false_when_gamepad_on_other_slot() -> void:
	_manager.bind_device(0, 1)
	assert_false(_manager.has_available_gamepad(),
		"Gamepad on slot 1, slot 0 only has MKB → no available gamepad")


# ============================================================================
# Query API
# ============================================================================

func test_get_player_for_device_returns_0_for_unbound() -> void:
	assert_eq(_manager.get_player_for_device(99), 0,
		"Unbound device should default to slot 0")


func test_get_devices_for_player_empty_for_inactive_slot() -> void:
	assert_eq(_manager.get_devices_for_player(99).size(), 0,
		"Inactive slot should return empty array")


func test_get_devices_for_player_returns_all_devices() -> void:
	_manager.bind_device(0, 1)
	_manager.bind_device(1, 1)
	var devices = _manager.get_devices_for_player(1)
	assert_eq(devices.size(), 2)
	assert_true(0 in devices)
	assert_true(1 in devices)


# ============================================================================
# Hotplug
# ============================================================================

func test_gamepad_connect_auto_binds_to_slot_0() -> void:
	_manager._on_joy_connection_changed(0, true)
	assert_eq(_manager.get_player_for_device(0), 0,
		"New gamepad should auto-bind to slot 0")
	assert_true(0 in _manager.get_devices_for_player(0),
		"Gamepad should be in slot 0's device list")


func test_gamepad_disconnect_unbinds_and_emits() -> void:
	_manager.bind_device(0, 1)
	watch_signals(_manager)
	_manager._on_joy_connection_changed(0, false)
	assert_eq(_manager.get_player_for_device(0), 0,
		"Disconnected gamepad should default to slot 0")
	assert_signal_emitted_with_parameters(_manager.device_unbound, [0, 1])


func test_gamepad_disconnect_cleans_empty_slot() -> void:
	_manager.bind_device(0, 2)
	assert_true(_manager._slot_to_devices.has(2))
	_manager._on_joy_connection_changed(0, false)
	assert_false(_manager._slot_to_devices.has(2),
		"Slot 2 should be removed when its last device disconnects")


# ============================================================================
# Slot Signals
# ============================================================================

func test_slot_activated_emitted_when_slot_becomes_active() -> void:
	_manager.bind_device(0, 0)  # gamepad 0 on slot 0 (already has MKB) — no new slot
	watch_signals(_manager)
	_manager.bind_device(1, 1)  # gamepad 1 on slot 1 — new slot!
	assert_signal_emitted_with_parameters(_manager.slot_activated, [1])


func test_slot_activated_not_emitted_when_slot_already_active() -> void:
	_manager.bind_device(0, 1)  # gamepad 0 activates slot 1
	watch_signals(_manager)
	_manager.bind_device(1, 1)  # gamepad 1 also on slot 1 — already active
	assert_signal_not_emitted(_manager.slot_activated)


func test_slot_deactivated_emitted_when_slot_becomes_empty() -> void:
	_manager.bind_device(0, 1)
	watch_signals(_manager)
	_manager.unbind_device(0)  # slot 1 becomes empty
	assert_signal_emitted_with_parameters(_manager.slot_deactivated, [1])


func test_slot_deactivated_not_emitted_for_primary_slot() -> void:
	_manager.bind_device(0, 0)  # gamepad 0 on primary slot
	watch_signals(_manager)
	_manager.unbind_device(0)  # primary slot still has MKB, never deactivates
	assert_signal_not_emitted(_manager.slot_deactivated)


func test_slot_deactivated_not_emitted_when_slot_still_has_devices() -> void:
	_manager.bind_device(0, 1)
	_manager.bind_device(1, 1)  # slot 1 has 2 devices
	watch_signals(_manager)
	_manager.unbind_device(0)  # slot 1 still has device 1
	assert_signal_not_emitted(_manager.slot_deactivated)


func test_slot_activated_and_deactivated_on_move() -> void:
	# Move gamepad from slot 1 to slot 2. Slot 1 deactivates, slot 2 activates.
	_manager.bind_device(0, 1)
	watch_signals(_manager)
	_manager.bind_device(0, 2)
	assert_signal_emitted_with_parameters(_manager.slot_deactivated, [1])
	assert_signal_emitted_with_parameters(_manager.slot_activated, [2])



# ============================================================================
# Edge Cases
# ============================================================================

func test_sparse_slots_are_valid() -> void:
	_manager.bind_device(0, 3)
	_manager.bind_device(1, 7)
	var slots = _manager.get_active_slots()
	assert_eq(slots.size(), 3, "Should have slots 0, 3, 7")
	assert_true(0 in slots)
	assert_true(3 in slots)
	assert_true(7 in slots)


func test_rebind_preserves_other_slot_devices() -> void:
	_manager.bind_device(0, 1)
	_manager.bind_device(1, 1)
	_manager.bind_device(0, 2)  # move gamepad 0 to slot 2

	assert_eq(_manager.get_devices_for_player(1).size(), 1,
		"Slot 1 should still have gamepad 1")
	assert_eq(_manager.get_player_for_device(1), 1,
		"Gamepad 1 should still be on slot 1")


func test_bind_then_unbind_restores_initial_state() -> void:
	var initial_slots = _manager.get_active_slots()
	var initial_active = _manager.get_active_players()

	_manager.bind_device(0, 1)
	_manager.unbind_device(0)

	assert_eq(_manager.get_active_slots(), initial_slots,
		"Active slots should match initial state")
	assert_eq(_manager.get_active_players(), initial_active,
		"Active player count should match initial state")


func test_multiple_devices_on_primary_slot() -> void:
	_manager.bind_device(0, 0)
	_manager.bind_device(1, 0)
	assert_eq(_manager.get_devices_for_player(0).size(), 3,
		"Slot 0 should have MKB + 2 gamepads")
	assert_true(_manager.has_available_gamepad())
