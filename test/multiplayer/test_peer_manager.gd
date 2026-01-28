extends GutTest

var _peer_manager: PeerManagerCode
var _provider_double: BaseNetworkProvider

func before_each():
	_peer_manager = PeerManagerCode.new()
	add_child(_peer_manager)
	
	# Create a double of the provider
	_provider_double = double(BaseNetworkProvider).new()
	# BaseNetworkProvider is RefCounted, so no add_child needed
	
	# Spy on the provider
	watch_signals(_provider_double)
func after_each():
	_peer_manager.shutdown()
	_peer_manager.free()
	_provider_double = null

func test_host_game_emits_attempt():
	_peer_manager.set_provider(_provider_double)
	watch_signals(_peer_manager)
	
	_peer_manager.host_game()
	
	assert_signal_emitted(_peer_manager.connection_attempt_started, "Should emit connection attempt started")
	assert_called(_provider_double.host_game)

func test_connection_created_sets_peer():
	_peer_manager.set_provider(_provider_double)
	watch_signals(_peer_manager)
	
	# We need to pass a mock peer
	var mock_peer = ENetMultiplayerPeer.new()
	mock_peer.create_server(8910) # Initialize peer to ensure it's valid for assignment
	
	# Simulate the signal emission from the provider
	_provider_double.connection_created.emit(mock_peer)
	
	assert_signal_emitted(_peer_manager.connection_established, "Should emit connection_established")
	assert_eq(_peer_manager.multiplayer.multiplayer_peer, mock_peer, "Multiplayer peer should be set")

func test_shutdown_cleans_up():
	_peer_manager.set_provider(_provider_double)
	
	# Set some state to clear
	_peer_manager.multiplayer.multiplayer_peer = ENetMultiplayerPeer.new()
	
	_peer_manager.shutdown()
	
	assert_null(_peer_manager.multiplayer.multiplayer_peer, "Multiplayer peer should be null after shutdown")
	assert_called(_provider_double.shutdown)

func test_set_provider_replaces_old():
	_peer_manager.set_provider(_provider_double)
	
	var new_provider = double(BaseNetworkProvider).new()
	_peer_manager.set_provider(new_provider)
	
	assert_called(_provider_double.shutdown)
	assert_false(
		_provider_double.connection_created.is_connected(_peer_manager._on_provider_connection_created),
		"Should disconnect old signals"
	)

func test_set_provider_ignores_redundant():
	_peer_manager.set_provider(_provider_double)
	# This should hit the early return
	_peer_manager.set_provider(_provider_double)
	
	assert_not_called(_provider_double.shutdown)
	assert_true(
		_provider_double.connection_created.is_connected(_peer_manager._on_provider_connection_created),
		"Signals should remain connected on redundant set"
	)

func test_join_game_emits_attempt():
	_peer_manager.set_provider(_provider_double)
	watch_signals(_peer_manager)
	
	_peer_manager.join_game()
	
	assert_signal_emitted(_peer_manager.connection_attempt_started)
	assert_called(_provider_double.join_game)

func test_host_no_provider_emits_shutdown():
	_peer_manager.set_provider(null)
	watch_signals(_peer_manager)
	
	_peer_manager.host_game()
	
	assert_signal_emitted_with_parameters(_peer_manager.connection_shutdown, ["No provider set."])

func test_provider_failure_emits_shutdown():
	_peer_manager.set_provider(_provider_double)
	watch_signals(_peer_manager)
	
	_provider_double.connection_failed.emit("Auth failed")
	
	assert_signal_emitted_with_parameters(_peer_manager.connection_shutdown, ["Auth failed"])

func test_multiplayer_connect_emits_established():
	# In Godot, multiplayer is a property of Node. 
	# We can simulate the signal emission from the SceneMultiplayer instance.
	watch_signals(_peer_manager)
	
	_peer_manager.multiplayer.connected_to_server.emit()
	
	assert_signal_emitted(_peer_manager.connection_established, "Should forward connected_to_server to connection_established")

func test_multiplayer_disconnect_emits_shutdown():
	watch_signals(_peer_manager)
	
	_peer_manager.multiplayer.server_disconnected.emit()
	assert_signal_emitted_with_parameters(_peer_manager.connection_shutdown, ["Server disconnected."])
	
	_peer_manager.multiplayer.connection_failed.emit()
	assert_signal_emitted_with_parameters(_peer_manager.connection_shutdown, ["Connection failed."])

func test_client_ignores_provider_connection():
	_peer_manager.set_provider(_provider_double)
	watch_signals(_peer_manager)

	var mock_peer = ENetMultiplayerPeer.new()
	_provider_double.connection_created.emit(mock_peer)
	
	# Since is_server() is false (no server peer created), it should NOT emit connection_established
	assert_signal_not_emitted(
		_peer_manager.connection_established,
		"Should NOT emit connection_established for non-server in provider callback"
	)
