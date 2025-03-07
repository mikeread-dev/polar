import 'package:flutter/services.dart';
import 'exceptions.dart';

class PolarErrorMapper {
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
