extends GutTest

## Unit tests for the device-mapping building blocks:
## SeatSnapshot.


class TestSeatSnapshot:
	extends GutTest

	var _manager: LocalCoopManagerCode

	func before_each() -> void:
		var mock = double(InputProvider).new()
		stub(mock, "get_connected_joypads").to_return([])
		_manager = LocalCoopManagerCode.new()
		_manager.input_provider = mock
		add_child_autofree(_manager)

	func test_capture_and_restore() -> void:
		_manager.bind_device(0, 1)
		var snap := SeatSnapshot.new()
		snap.capture(_manager)
		_manager.bind_device(0, 2)
		assert_eq(_manager.get_player_for_device(0), 2, "Sanity: device moved to slot 2")
		snap.restore(_manager)
		assert_eq(_manager.get_player_for_device(0), 1, "Restore should put device back on slot 1")

	func test_get_seat_defaults_to_primary() -> void:
		var snap := SeatSnapshot.new()
		snap.capture(_manager)
		assert_eq(snap.get_seat(99), LocalCoopManagerCode.PRIMARY_SLOT, "Unknown device defaults to primary slot")

	func test_restore_sends_hotplugged_pad_to_primary_slot() -> void:
		var snap := SeatSnapshot.new()
		snap.capture(_manager)

		# Pad 5 connected mid-modal and moved to seat 2
		_manager.bind_device(5, 2)
		snap.restore(_manager)

		assert_eq(_manager.get_player_for_device(5), LocalCoopManagerCode.PRIMARY_SLOT,
			"Hotplugged unknown pad should restore to seat 0")
		assert_true(5 in _manager.get_devices_for_player(0))

	func test_restore_does_not_rebind_unplugged_pad() -> void:
		_manager.bind_device(0, 1)
		var snap := SeatSnapshot.new()
		snap.capture(_manager)

		# Pad 0 unplugged mid-modal
		_manager.unbind_device(0)
		snap.restore(_manager)

		assert_false(0 in _manager.get_devices_for_player(1),
			"Unplugged pad must not be ghost-rebound on restore")
		assert_false(0 in _manager.get_devices_for_player(0),
			"Unplugged pad must remain unbound")
