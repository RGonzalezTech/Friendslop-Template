class_name DeviceVisualFactory
extends RefCounted

## Maps a [enum DeviceVisual.DeviceType] to a concrete [DeviceVisual].
##
## Injected into [DeviceMappingModal] so the visual set can be swapped (a themed
## gamepad, a new device type) without editing the modal, column, or row.
##
##   var factory := DeviceVisualFactory.new()
##   factory.register(DeviceVisual.DeviceType.GAMEPAD, func() -> DeviceVisual:
##       return MyGamepadVisual.new())
##   var visual := factory.create(DeviceVisual.DeviceType.GAMEPAD)

## Optional per-type constructor overrides: DeviceType -> Callable() -> DeviceVisual.
var _overrides: Dictionary = {}

## Resolves which [enum DeviceVisual.DeviceType] a raw device id represents.
static func type_for_device(device_id: int) -> DeviceVisual.DeviceType:
	return DeviceVisual.DeviceType.KEYBOARD_MOUSE if device_id < 0 else DeviceVisual.DeviceType.GAMEPAD

## Constructs a visual for [param device_type]. Falls back to the built-ins.
func create(device_type: DeviceVisual.DeviceType) -> DeviceVisual:
	if _overrides.has(device_type):
		return _overrides[device_type].call()
	match device_type:
		DeviceVisual.DeviceType.KEYBOARD_MOUSE:
			return KeyboardVisual.new()
		DeviceVisual.DeviceType.GAMEPAD:
			return GamepadVisual.new()
		_:
			push_warning("DeviceVisualFactory: unknown type %d, falling back to keyboard." % device_type)
			return KeyboardVisual.new()

## Registers or replaces the constructor for [param device_type].
func register(device_type: DeviceVisual.DeviceType, constructor: Callable) -> void:
	_overrides[device_type] = constructor
