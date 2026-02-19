extends GutTest

var _timer: HandshakeRetryTimer

func before_each():
	_timer = HandshakeRetryTimer.new()
	add_child_autofree(_timer)

func test_initialization():
	assert_eq(_timer.wait_time, 0.25, "Default wait time should be 0.25")
	assert_false(_timer.is_stopped(), "Should be running")
	assert_false(_timer.one_shot, "Should not be one_shot")

func test_timeout_emits_sync_requested():
	watch_signals(_timer)
	
	# Wait for timeout (0.25s + buffer)
	await wait_seconds(0.3)
	
	assert_signal_emitted(_timer.sync_requested, "Should emit sync_requested on timeout")

func test_ack_stops_timer_and_emits_complete():
	watch_signals(_timer)
	
	_timer.ack()
	
	assert_signal_emitted(_timer.handshake_complete, "Should emit handshake_complete on ack")
	assert_true(_timer.is_stopped(), "Timer should be stopped after ack")
	# Accessing private var for test verification is acceptable in GDScript tests usually, 
	# but strictly we should test behavior. _is_synced is private but vital for the logic.
	# We can verify the "synced" behavior by forcing another timeout.

func test_timeout_after_ack_does_nothing():
	_timer.ack()
	watch_signals(_timer)
	
	# Restart manually to force a timeout, simulating a race or incorrect restart
	_timer.start(0.1)
	await wait_seconds(0.2)
	
	assert_signal_not_emitted(_timer.sync_requested, "Should NOT emit sync_requested if synced")
	assert_true(_timer.is_stopped(), "Should ensure timer is stopped if timeout happens when synced")
