import 'package:flutter/services.dart';
import 'package:polar/src/exceptions.dart';

/// Maps platform-specific errors to Polar SDK exceptions
class PolarErrorMapper {
  /// Converts a [PlatformException] to the appropriate [PolarException]
  /// 
  /// Parameters:
  ///   - [e]: The platform exception to convert
  /// 
  /// Returns the appropriate Polar exception based on the error code
  static Exception mapPlatformError(PlatformException e) {
    switch (e.code) {
      case 'device_disconnected':
        return PolarDeviceDisconnectedException(
          'Device disconnected unexpectedly',
          e,
        );
      case 'not_supported':
        return PolarNotSupportedException(
          'Feature not supported on this device',
          e,
        );
      case 'bluetooth_error':
        return PolarBluetoothOperationException(
          'Bluetooth operation failed: ${e.message}',
          e,
        );
      default:
        return PolarDataException('Unknown error: ${e.message}');
    }
  }
}
