/// Base class for all Polar SDK exceptions
abstract class PolarException implements Exception {
  /// A descriptive message explaining the error
  final String message;

  /// The underlying cause of the exception, if any
  final dynamic cause;

  /// Creates a new [PolarException] with the given [message] and optional [cause]
  PolarException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? '$message: $cause' : message;
}

/// Thrown when a Bluetooth operation fails
/// 
/// This can occur due to various reasons such as:
/// - Communication errors
/// - Invalid responses
/// - Hardware issues
class PolarBluetoothOperationException extends PolarException {
  /// Creates a new [PolarBluetoothOperationException] with the given [message] and optional [cause]
  PolarBluetoothOperationException(super.message, [super.cause]);
}

/// Thrown when a device is not connected
/// 
/// This occurs when trying to perform operations on a device that:
/// - Was never connected
/// - Has disconnected
/// - Lost connection
class PolarDeviceDisconnectedException extends PolarException {
  /// Creates a new [PolarDeviceDisconnectedException] with the given [message] and optional [cause]
  PolarDeviceDisconnectedException(super.message, [super.cause]);
}

/// Thrown when a device is not found
/// 
/// This occurs when:
/// - The specified device ID doesn't exist
/// - The device is out of range
/// - The device is not advertising
class PolarDeviceNotFoundException extends PolarException {
  /// Creates a new [PolarDeviceNotFoundException] with the given [message] and optional [cause]
  PolarDeviceNotFoundException(super.message, [super.cause]);
}

/// Thrown when an operation times out
/// 
/// This occurs when:
/// - A device doesn't respond within the expected timeframe
/// - A connection attempt takes too long
/// - An operation exceeds its time limit
class PolarTimeoutException extends PolarException {
  /// Creates a new [PolarTimeoutException] with the given [message] and optional [cause]
  PolarTimeoutException(super.message, [super.cause]);
}

/// Thrown when an invalid parameter is provided
/// 
/// This occurs when:
/// - A parameter is null when it shouldn't be
/// - A value is out of the expected range
/// - A string format is invalid
class PolarInvalidArgumentException extends PolarException {
  /// Creates a new [PolarInvalidArgumentException] with the given [message] and optional [cause]
  PolarInvalidArgumentException(super.message, [super.cause]);
}

/// Thrown when a feature is not supported by the device
/// 
/// This occurs when:
/// - Trying to use features not available on the specific device model
/// - The device firmware doesn't support the requested operation
/// - The feature requires capabilities the device doesn't have
class PolarNotSupportedException extends PolarException {
  /// Creates a new [PolarNotSupportedException] with the given [message] and optional [cause]
  PolarNotSupportedException(super.message, [super.cause]);
}

/// Thrown when there's an error with the device's operation mode
/// 
/// This occurs when:
/// - The device is in an incompatible state for the requested operation
/// - Required prerequisites aren't met
/// - The operation conflicts with current device settings
class PolarOperationNotAllowedException extends PolarException {
  /// Creates a new [PolarOperationNotAllowedException] with the given [message] and optional [cause]
  PolarOperationNotAllowedException(super.message, [super.cause]);
}

/// Thrown when there's an error with data parsing or serialization
/// 
/// This occurs when:
/// - Received data is corrupted
/// - Data format is unexpected
/// - Conversion between formats fails
class PolarDataException extends PolarException {
  /// Creates a new [PolarDataException] with the given [message] and optional [cause]
  PolarDataException(super.message, [super.cause]);
}

/// Thrown when there's an error with the device's security
/// 
/// This occurs when:
/// - Authentication fails
/// - Encryption/decryption errors
/// - Security protocol violations
class PolarSecurityException extends PolarException {
  /// Creates a new [PolarSecurityException] with the given [message] and optional [cause]
  PolarSecurityException(super.message, [super.cause]);
}

/// Thrown when there's an error with the device's settings
/// 
/// This occurs when:
/// - Invalid setting values are used
/// - Settings conflicts occur
/// - Settings cannot be applied
class PolarSettingException extends PolarException {
  /// Creates a new [PolarSettingException] with the given [message] and optional [cause]
  PolarSettingException(super.message, [super.cause]);
}

/// Thrown when there's an error with recording operations
/// 
/// This occurs when:
/// - Recording cannot start/stop
/// - Storage issues
/// - Recording conflicts
class PolarRecordingException extends PolarException {
  /// Creates a new [PolarRecordingException] with the given [message] and optional [cause]
  PolarRecordingException(super.message, [super.cause]);
}
