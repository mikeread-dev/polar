import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polar/polar.dart';
import 'package:polar/src/model/convert.dart';

/// Flutter implementation of the [PolarBleSdk]
class Polar {
  static const _channel = MethodChannel('polar');
  static const _searchChannel = EventChannel('polar/search');

  static Polar? _instance;

  // Other data
  final _blePowerState = StreamController<bool>.broadcast();
  final _sdkFeatureReady =
      StreamController<PolarSdkFeatureReadyEvent>.broadcast();
  final _deviceConnected = StreamController<PolarDeviceInfo>.broadcast();
  final _deviceConnecting = StreamController<PolarDeviceInfo>.broadcast();
  final _deviceDisconnected =
      StreamController<PolarDeviceDisconnectedEvent>.broadcast();
  final _disInformation =
      StreamController<PolarDisInformationEvent>.broadcast();
  final _batteryLevel = StreamController<PolarBatteryLevelEvent>.broadcast();

  /// helper to ask ble power state
  Stream<bool> get blePowerState => _blePowerState.stream;

  /// feature ready callback
  Stream<PolarSdkFeatureReadyEvent> get sdkFeatureReady =>
      _sdkFeatureReady.stream;

  /// Device connection has been established.
  ///
  /// - Parameter identifier: Polar device info
  Stream<PolarDeviceInfo> get deviceConnected => _deviceConnected.stream;

  /// Callback when connection attempt is started to device
  ///
  /// - Parameter identifier: Polar device info
  Stream<PolarDeviceInfo> get deviceConnecting => _deviceConnecting.stream;

  /// Connection lost to device.
  /// If PolarBleApi#disconnectFromPolarDevice is not called, a new connection attempt is dispatched automatically.
  ///
  /// - Parameter identifier: Polar device info
  Stream<PolarDeviceDisconnectedEvent> get deviceDisconnected =>
      _deviceDisconnected.stream;

  ///  Received DIS info.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id
  ///   - fwVersion: firmware version in format major.minor.patch
  Stream<PolarDisInformationEvent> get disInformation => _disInformation.stream;

  /// Battery level received from device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id
  ///   - batteryLevel: battery level in precentage 0-100%
  Stream<PolarBatteryLevelEvent> get batteryLevel => _batteryLevel.stream;

  /// Will request location permission on Android S+ if false
  final bool _bluetoothScanNeverForLocation;

  Polar._(this._bluetoothScanNeverForLocation) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Initialize the Polar API. Returns a singleton.
  ///
  /// DartDocs are copied from the iOS version of the SDK and are only included for reference
  ///
  /// The plugin will request location permission on Android S+ if [bluetoothScanNeverForLocation] is false
  factory Polar({bool bluetoothScanNeverForLocation = true}) =>
      _instance ??= Polar._(bluetoothScanNeverForLocation);

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'blePowerStateChanged':
        _blePowerState.add(call.arguments);
        return;
      case 'sdkFeatureReady':
        _sdkFeatureReady.add(
          PolarSdkFeatureReadyEvent(
            call.arguments[0],
            PolarSdkFeature.fromJson(call.arguments[1]),
          ),
        );
        return;
      case 'deviceConnected':
        _deviceConnected
            .add(PolarDeviceInfo.fromJson(jsonDecode(call.arguments)));
        return;
      case 'deviceConnecting':
        _deviceConnecting
            .add(PolarDeviceInfo.fromJson(jsonDecode(call.arguments)));
        return;
      case 'deviceDisconnected':
        _deviceDisconnected.add(
          PolarDeviceDisconnectedEvent(
            PolarDeviceInfo.fromJson(jsonDecode(call.arguments[0])),
            call.arguments[1],
          ),
        );
        return;
      case 'disInformationReceived':
        _disInformation.add(
          PolarDisInformationEvent(
            call.arguments[0],
            call.arguments[1],
            call.arguments[2],
          ),
        );
        return;
      case 'batteryLevelReceived':
        _batteryLevel.add(
          PolarBatteryLevelEvent(
            call.arguments[0],
            call.arguments[1],
          ),
        );
        return;
      default:
        throw UnimplementedError(call.method);
    }
  }

  /// Start searching for Polar device(s)
  ///
  /// - Parameter onNext: Invoked once for each device
  /// - Returns: Observable stream
  ///  - onNext: for every new polar device found
  Stream<PolarDeviceInfo> searchForDevice() {
    return _searchChannel.receiveBroadcastStream().map(
          (event) => PolarDeviceInfo.fromJson(jsonDecode(event)),
        );
  }

  /// Request a connection to a Polar device. Invokes `PolarBleApiObservers` polarDeviceConnected.
  /// - Parameter identifier: Polar device id printed on the sensor/device or UUID.
  /// - Throws: InvalidArgument if identifier is invalid polar device id or invalid uuid
  ///
  /// Will request the necessary permissions if [requestPermissions] is true
  Future<void> connectToDevice(
    String identifier, {
    bool requestPermissions = true,
  }) async {
    if (requestPermissions) {
      await this.requestPermissions();
    }
    try {
      unawaited(_channel.invokeMethod('connectToDevice', identifier));
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to start offline recording: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error starting offline recording: $e');
    }
  }

  /// Request the necessary permissions on Android
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidDeviceInfo.version.sdkInt;

      // If we are on Android M+
      if (sdkInt >= 23) {
        // If we are on an Android version before S or bluetooth scan is used to derive location
        if (sdkInt < 31 || !_bluetoothScanNeverForLocation) {
          await Permission.location.request();
        }
        // If we are on Android S+
        if (sdkInt >= 31) {
          await Permission.bluetoothScan.request();
          await Permission.bluetoothConnect.request();
        }
      }
    }
  }

  /// Disconnect from the current Polar device.
  ///
  /// - Parameter identifier: Polar device id
  /// - Throws: InvalidArgument if identifier is invalid polar device id or invalid uuid
  Future<void> disconnectFromDevice(String identifier) {
    try {
      return _channel.invokeMethod('disconnectFromDevice', identifier);
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to start offline recording: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error starting offline recording: $e');
    }
  }

  ///  Get the data types available in this device for online streaming
  ///
  /// - Parameters:
  ///   - identifier: polar device id
  /// - Returns: Single stream
  ///   - success: set of available online streaming data types in this device
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<Set<PolarDataType>> getAvailableOnlineStreamDataTypes(
    String identifier,
  ) async {
    final response = await _channel.invokeMethod(
      'getAvailableOnlineStreamDataTypes',
      identifier,
    );
    if (response == null) return {};
    return (jsonDecode(response) as List).map(PolarDataType.fromJson).toSet();
  }

  ///  Request the stream settings available in current operation mode. This request shall be used before the stream is started
  ///  to decide currently available settings. The available settings depend on the state of the device. For example, if any stream(s)
  ///  or optical heart rate measurement is already enabled, then the device may limit the offer of possible settings for other stream feature.
  ///  Requires `polarSensorStreaming` feature.
  ///
  /// - Parameters:
  ///   - identifier: polar device id
  ///   - feature: selected feature from`PolarDeviceDataType`
  /// - Returns: Single stream
  ///   - success: once after settings received from device
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<PolarSensorSetting> requestStreamSettings(
    String identifier,
    PolarDataType feature,
  ) async {
    final response = await _channel.invokeMethod(
      'requestStreamSettings',
      [identifier, feature.toJson()],
    );
    return PolarSensorSetting.fromJson(jsonDecode(response));
  }

  Stream<Map<String, dynamic>> _startStreaming(
    PolarDataType feature,
    String identifier, {
    PolarSensorSetting? settings,
  }) async* {
    assert(settings == null || settings.isSelection);

    final channelName = 'polar/streaming/$identifier/${feature.name}';

    await _channel.invokeMethod('createStreamingChannel', [
      channelName,
      identifier,
      feature.toJson(),
    ]);

    if (settings == null && feature.supportsStreamSettings) {
      final availableSettings = await requestStreamSettings(
        identifier,
        feature,
      );
      settings = availableSettings.maxSettings();
    }

    yield* EventChannel(channelName)
        .receiveBroadcastStream(jsonEncode(settings))
        .cast<String>()
        .map(jsonDecode)
        .cast<Map<String, dynamic>>();
  }

  /// Start heart rate stream. Heart rate stream is stopped if the connection is closed,
  /// error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarHrData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarHrData> startHrStreaming(String identifier) {
    return _startStreaming(PolarDataType.hr, identifier)
        .map(PolarHrData.fromJson);
  }

  /// Start the ECG (Electrocardiography) stream. ECG stream is stopped if the connection is closed, error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarEcgData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarEcgData> startEcgStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.ecg,
      identifier,
      settings: settings,
    ).map(PolarEcgData.fromJson);
  }

  ///  Start ACC (Accelerometer) stream. ACC stream is stopped if the connection is closed, error occurs or stream is disposed.
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarAccData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarAccData> startAccStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.acc,
      identifier,
      settings: settings,
    ).map(PolarAccData.fromJson);
  }

  /// Start Gyro stream. Gyro stream is stopped if the connection is closed, error occurs during start or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  Stream<PolarGyroData> startGyroStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.gyro,
      identifier,
      settings: settings,
    ).map(PolarGyroData.fromJson);
  }

  /// Start magnetometer stream. Magnetometer stream is stopped if the connection is closed, error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  Stream<PolarMagnetometerData> startMagnetometerStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.magnetometer,
      identifier,
      settings: settings,
    ).map(PolarMagnetometerData.fromJson);
  }

  /// Start optical sensor PPG (Photoplethysmography) stream. PPG stream is stopped if the connection is closed, error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarPpgData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarPpgData> startPpgStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.ppg,
      identifier,
      settings: settings,
    ).map(PolarPpgData.fromJson);
  }

  /// Start PPI (Pulse to Pulse interval) stream.
  /// PPI stream is stopped if the connection is closed, error occurs or stream is disposed.
  /// Notice that there is a delay before PPI data stream starts.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarPpiData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarPpiData> startPpiStreaming(String identifier) {
    return _startStreaming(PolarDataType.ppi, identifier)
        .map(PolarPpiData.fromJson);
  }

  /// Start temperature stream. Temperature stream is stopped if the connection is closed,
  /// error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarTemperatureData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarTemperatureData> startTemperatureStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.temperature,
      identifier,
      settings: settings,
    ).map(PolarTemperatureData.fromJson);
  }

  /// Start pressure stream. Pressure stream is stopped if the connection is closed,
  /// error occurs or stream is disposed.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - settings: selected settings to start the stream
  /// - Returns: Observable stream
  ///   - onNext: for every air packet received. see `PolarPressureData`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Stream<PolarPressureData> startPressureStreaming(
    String identifier, {
    PolarSensorSetting? settings,
  }) {
    return _startStreaming(
      PolarDataType.pressure,
      identifier,
      settings: settings,
    ).map(PolarPressureData.fromJson);
  }

  /// Request start recording. Supported only by Polar H10. Requires `polarFileTransfer` feature.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or UUID
  ///   - exerciseId: unique identifier for for exercise entry length from 1-64 bytes
  ///   - interval: recording interval to be used. Has no effect if `sampleType` is `SampleType.rr`
  ///   - sampleType: sample type to be used.
  /// - Returns: Completable stream
  ///   - success: recording started
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<void> startRecording(
    String identifier, {
    required String exerciseId,
    required RecordingInterval interval,
    required SampleType sampleType,
  }) {
    return _channel.invokeMethod(
      'startRecording',
      [identifier, exerciseId, interval.toJson(), sampleType.toJson()],
    );
  }

  /// Request stop for current recording. Supported only by Polar H10. Requires `polarFileTransfer` feature.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or UUID
  /// - Returns: Completable stream
  ///   - success: recording stopped
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<void> stopRecording(String identifier) {
    return _channel.invokeMethod('stopRecording', identifier);
  }

  /// Request current recording status. Supported only by Polar H10. Requires `polarFileTransfer` feature.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id
  /// - Returns: Single stream
  ///   - success: see `PolarRecordingStatus`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<PolarRecordingStatus> requestRecordingStatus(String identifier) async {
    final result =
        await _channel.invokeListMethod('requestRecordingStatus', identifier);

    return PolarRecordingStatus(ongoing: result![0], entryId: result[1]);
  }

  /// Api for fetching stored exercises list from Polar H10 device. Requires `polarFileTransfer` feature. This API is working for Polar OH1 and Polar Verity Sense devices too, however in those devices recording of exercise requires that sensor is registered to Polar Flow account.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  /// - Returns: Observable stream
  ///   - onNext: see `PolarExerciseEntry`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<List<PolarExerciseEntry>> listExercises(String identifier) async {
    final result = await _channel.invokeListMethod('listExercises', identifier);
    if (result == null) {
      return [];
    }
    return result
        .cast<String>()
        .map((e) => PolarExerciseEntry.fromJson(jsonDecode(e)))
        .toList();
  }

  /// Api for fetching a single exercise from Polar H10 device. Requires `polarFileTransfer` feature. This API is working for Polar OH1 and Polar Verity Sense devices too, however in those devices recording of exercise requires that sensor is registered to Polar Flow account.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - entry: single exercise entry to be fetched
  /// - Returns: Single stream
  ///   - success: invoked after exercise data has been fetched from the device. see `PolarExerciseEntry`
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<PolarExerciseData> fetchExercise(
    String identifier,
    PolarExerciseEntry entry,
  ) async {
    final result = await _channel
        .invokeMethod('fetchExercise', [identifier, jsonEncode(entry)]);
    return PolarExerciseData.fromJson(jsonDecode(result));
  }

  /// Api for removing single exercise from Polar H10 device. Requires `polarFileTransfer` feature. This API is working for Polar OH1 and Polar Verity Sense devices too, however in those devices recording of exercise requires that sensor is registered to Polar Flow account.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or device address
  ///   - entry: single exercise entry to be removed
  /// - Returns: Completable stream
  ///   - complete: entry successfully removed
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<void> removeExercise(String identifier, PolarExerciseEntry entry) {
    return _channel
        .invokeMethod('removeExercise', [identifier, jsonEncode(entry)]);
  }

  /// Set [LedConfig] to enable or disable blinking LEDs (Verity Sense 2.2.1+).
  ///
  /// - Parameters:
  ///   - identifier: polar device id or UUID
  ///   - ledConfig: to enable or disable LEDs blinking
  /// - Returns: Completable stream
  ///   - success: when enable or disable sent to device
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<void> setLedConfig(String identifier, LedConfig config) {
    return _channel
        .invokeMethod('setLedConfig', [identifier, jsonEncode(config)]);
  }

  /// Perform factory reset to given device.
  ///
  /// - Parameters:
  ///   - identifier: polar device id or UUID
  ///   - preservePairingInformation: preserve pairing information during factory reset
  /// - Returns: Completable stream
  ///   - success: when factory reset notification sent to device
  ///   - onError: see `PolarErrors` for possible errors invoked
  Future<void> doFactoryReset(
    String identifier,
    bool preservePairingInformation,
  ) {
    return _channel.invokeMethod(
      'doFactoryReset',
      [identifier, preservePairingInformation],
    );
  }

  ///  Enables SDK mode.
  Future<void> enableSdkMode(String identifier) {
    return _channel.invokeMethod('enableSdkMode', identifier);
  }

  /// Disables SDK mode.
  Future<void> disableSdkMode(String identifier) {
    return _channel.invokeMethod('disableSdkMode', identifier);
  }

  /// Check if SDK mode currently enabled.
  ///
  /// Note, SDK status check is supported by VeritySense starting from firmware 2.1.0
  Future<bool> isSdkModeEnabled(String identifier) async {
    final result =
        await _channel.invokeMethod<bool>('isSdkModeEnabled', identifier);
    return result!;
  }

  /// Fetches the available offline recording data types for a given Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  /// - Returns: A list of available offline recording data types in JSON format.
  ///   - success: Returns a set of PolarDataType representing available data types.
  ///   - onError: Possible errors are returned as exceptions.
  Future<Set<PolarDataType>> getAvailableOfflineRecordingDataTypes(
    String identifier,
  ) async {
    final response = await _channel.invokeMethod(
      'getAvailableOfflineRecordingDataTypes',
      identifier,
    );

    if (response == null) return {};
    return (jsonDecode(response) as List).map(PolarDataType.fromJson).toSet();
  }

  /// Requests the offline recording settings for a specific data type.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - feature: The data type for which settings are requested.
  /// - Returns: Offline recording settings in JSON format.
  ///   - success: Returns a map of settings.
  ///   - onError: Possible errors are returned as exceptions.
  Future<PolarSensorSetting?> requestOfflineRecordingSettings(
    String identifier,
    PolarDataType feature,
  ) async {
    final response = await _channel.invokeMethod<String>(
      'requestOfflineRecordingSettings',
      [identifier, feature.toJson()],
    );

    return response != null
        ? PolarSensorSetting.fromJson(jsonDecode(response))
        : null;
  }

  /// Starts offline recording on a Polar device with the given settings.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - feature: The data type to be recorded.
  ///   - settings: Recording settings in JSON format.
  ///   - encryptionKey: Optional encryption key for the recording.
  /// - Returns: Void.
  ///   - success: Invoked when recording starts successfully.
  ///   - onError: Possible errors are returned as exceptions.
  Future<void> startOfflineRecording(
    String identifier,
    PolarDataType feature, {
    PolarSensorSetting? settings,
  }) async {
    try {
      await _channel.invokeMethod(
        'startOfflineRecording',
        [
          identifier,
          feature.toJson(),
          settings != null ? jsonEncode(settings) : null,
        ],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to start offline recording: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error starting offline recording: $e');
    }
  }

  /// Stops offline recording for a specific data type on a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - feature: The data type to stop recording.
  /// - Returns: Void.
  ///   - success: Invoked when recording stops successfully.
  ///   - onError: Possible errors are returned as exceptions.
  Future<void> stopOfflineRecording(
    String identifier,
    PolarDataType feature,
  ) async {
    try {
      await _channel.invokeMethod(
        'stopOfflineRecording',
        [identifier, feature.toJson()],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device disconnected while stopping recording: ${e.message}', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to stop offline recording: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error stopping offline recording: $e');
    }
  }

  /// Checks the status of offline recording for a specific data type.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - feature: The data type to check the status for.
  /// - Returns: Recording status.
  ///   - success: Returns the recording status.
  ///   - onError: Possible errors are returned as exceptions.
  Future<List<PolarDataType>> getOfflineRecordingStatus(
    String identifier,
  ) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getOfflineRecordingStatus',
        [identifier],
      );

      if (result != null) {
        return result
            .map((e) => const PolarDataTypeConverter().fromJson(e))
            .toList();
      }
      return [];
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device disconnected while removing record: ${e.message}', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to get offline recording status: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error getting offline recording status: $e');
    }
  }

  /// Lists all offline recordings available on a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  /// - Returns: A list of recordings in JSON format.
  ///   - success: Returns a list of strings representing recording entries.
  ///   - onError: Possible errors are returned as exceptions.
  Future<List<PolarOfflineRecordingEntry>> listOfflineRecordings(
    String identifier,
  ) async {
    try {
      final result = await _channel.invokeListMethod(
        'listOfflineRecordings',
        identifier,
    );

    if (result == null) return [];

    return result
        .cast<String>()
        .map((e) => PolarOfflineRecordingEntry.fromJson(jsonDecode(e)))
        .toList();
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to list offline recordings: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error listing offline recordings: $e');
    }
  }

  /// Fetches a specific offline recording from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - entry: The entry representing the offline recording to fetch.
  /// - Returns: Recording data in JSON format.
  ///   - success: Returns the fetched recording data.
  ///   - onError: Possible errors are returned as exceptions.
  Future<AccOfflineRecording?> getOfflineAccRecord(
    String identifier,
    PolarOfflineRecordingEntry entry,
  ) async {
    final result = await _channel.invokeMethod<String>(
      'getOfflineRecord',
      [identifier, jsonEncode(entry.toJson())],
    );

    if (result == null) return null;
    final data = jsonDecode(result);
    return AccOfflineRecording.fromJson(data);
  }

  /// Fetches a specific offline recording from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - entry: The entry representing the offline recording to fetch.
  /// - Returns: Recording data in JSON format.
  ///   - success: Returns the fetched recording data.
  ///   - onError: Possible errors are returned as exceptions.
  Future<PpiOfflineRecording?> getOfflinePpiRecord(
    String identifier,
    PolarOfflineRecordingEntry entry,
  ) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getOfflineRecord',
        [identifier, jsonEncode(entry.toJson())],
      );
      if (result == null) return null;
      final data = jsonDecode(result);
      return PpiOfflineRecording.fromJson(data);
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to get offline ppi record: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error getting offline ppi record: $e');
    }
  }

  /// Fetches a specific offline recording from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - entry: The entry representing the offline recording to fetch.
  /// - Returns: Recording data in JSON format.
  ///   - success: Returns the fetched recording data.
  ///   - onError: Possible errors are returned as exceptions.
  Future<HrOfflineRecording?> getOfflineHrRecord(
    String identifier,
    PolarOfflineRecordingEntry entry,
  ) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getOfflineRecord',
        [identifier, jsonEncode(entry.toJson())],
      );
      if (result == null) return null;
      final data = jsonDecode(result);
      return HrOfflineRecording.fromJson(data);
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to get offline hr record: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error getting offline hr record: $e');
    }
  } 

  /// Fetches a specific offline recording from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - entry: The entry representing the offline recording to fetch.
  /// - Returns: Recording data in JSON format.
  ///   - success: Returns the fetched recording data.
  ///   - onError: Possible errors are returned as exceptions.
  Future<PpgOfflineRecording?> getOfflinePpgRecord(
    String identifier,
    PolarOfflineRecordingEntry entry,
  ) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getOfflineRecord',
        [identifier, jsonEncode(entry.toJson())],
    );
    if (result == null) return null;
    final data = jsonDecode(result);
    return PpgOfflineRecording.fromJson(data);
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to get offline ppg record: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error getting offline ppg record: $e');
    }
  }

  /// Removes a specific offline recording from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - entry: The entry representing the offline recording to remove.
  /// - Returns: Void.
  ///   - success: Invoked when the recording is removed successfully.
  ///   - onError: Possible errors are returned as exceptions.
  Future<void> removeOfflineRecord(
    String identifier,
    PolarOfflineRecordingEntry entry,
  ) async {
    try {
      await _channel.invokeMethod(
        'removeOfflineRecord',
        [identifier, jsonEncode(entry.toJson())],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          throw PolarFileNotFoundException('The offline record file was not found: ${e.message}', e);
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device disconnected while removing record: ${e.message}', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to remove offline record: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error removing offline record: $e');
    }
  }

  /// Sets the offline recording triggers for a given Polar device. The offline recording 
  /// can be started automatically in the device by setting the triggers. The changes to 
  /// the trigger settings will take effect on the next device startup.
  ///
  /// Automatically started offline recording can be stopped by stopOfflineRecording. 
  /// Also if user switches off the device power, the offline recording is stopped but 
  /// starts again once power is switched on and the trigger event happens.
  ///
  /// Trigger functionality can be disabled by setting PolarOfflineRecordingTriggerMode.triggerDisabled, 
  /// the already running offline recording is not stopped by disable.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - trigger: Type of trigger to set.
  /// - Returns: Void.
  ///   - success: The offline recording trigger was set successfully.
  ///   - onError: The offline recording trigger was not set successfully; see PolarErrors for possible errors.
  Future<void> setOfflineRecordingTrigger(
    String identifier,
    PolarOfflineRecordingTrigger trigger,
  ) async {
    try {
      await _channel.invokeMethod(
        'setOfflineRecordingTrigger',
        [identifier, jsonEncode(trigger.toJson())],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to set offline recording trigger: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error setting offline recording trigger: $e');
    }
  }


  /// Perform restart to given device.
  
  /// Update firmware on the device
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - firmwareUrl: Optional URL to specific firmware version. If empty, gets latest version.
  /// - Returns: Stream of firmware update status events
  ///   - onData: FirmwareUpdateEvent with status and details
  ///   - onError: See PolarErrors for possible errors invoked
  Stream<PolarFirmwareUpdateEvent> updateFirmware(String identifier, {String? firmwareUrl}) {
    try {
      // Start the firmware update via method channel
      _channel.invokeMethod('updateFirmware', [identifier, firmwareUrl ?? '']);
      
      // Listen to the firmware update events via event channel
      const eventChannel = EventChannel('polar/firmware_update');
      return eventChannel.receiveBroadcastStream().map((event) {
        final eventMap = Map<String, dynamic>.from(event as Map);
        return PolarFirmwareUpdateEvent.fromJson(eventMap);
      }).handleError((error) {
        if (error is PlatformException) {
          switch (error.code) {
            case 'device_disconnected':
              throw PolarDeviceDisconnectedException('Device $identifier is not connected', error);
            case 'not_supported':
              throw PolarOperationNotSupportedException('Firmware update not supported for device $identifier', error);
            case 'timeout':
              throw PolarDataException('Firmware update timed out for device $identifier: ${error.message}', error);
            case 'invalid_argument':
              throw PolarInvalidArgumentException('Invalid argument for firmware update: ${error.message}', error);
            case 'bluetooth_error':
              throw PolarDataException('Bluetooth error during firmware update: ${error.message}', error);
            default:
              throw PolarDataException('Firmware update failed: ${error.message}', error);
          }
        }
        throw PolarDataException('Firmware update failed: $error');
      });
    } catch (e) {
      throw PolarDataException('Failed to start firmware update: $e');
    }
  }

  ///
  /// - Parameters:
  ///   - identifier: Polar device id or UUID.
  ///   - preservePairingInformation: Preserve pairing information during restart.
  /// - Returns: Void.
  ///   - success: When restart notification sent to device.
  ///   - onError: See PolarErrors for possible errors invoked.
  Future<void> doRestart(
    String identifier, {
    bool preservePairingInformation = true,
  }) async {
    try {
      await _channel.invokeMethod(
        'doRestart',
        [identifier, preservePairingInformation],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to restart device: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error restarting device: $e');
    }
  }

  /// Fetches the available and used disk space on a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  /// - Returns: A list with two integers: available space and total space (in bytes).
  ///   - success: Returns a list containing the available and total space.
  ///   - onError: Possible errors are returned as exceptions.
  Future<List<int>> getDiskSpace(String identifier) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getDiskSpace',
        identifier,
      );
      return result?.map((e) => e as int).toList() ?? [];
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to get disk space: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error getting disk space: $e');
    }
  }

  /// Fetches the local time from a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  /// - Returns: The local time of the Polar device as a DateTime object.
  ///   - success: Returns the local time.
  ///   - onError: Possible errors are returned as exceptions.
  Future<DateTime?> getLocalTime(String identifier) async {
    try {
      final result = await _channel.invokeMethod<String>('getLocalTime', identifier);

      // If the result is null, return null
      if (result == null) return null;

      // Convert the string result to a DateTime object
      final time = DateTime.parse(result);

      return time;
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to get local time: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error getting local time: $e');
    }
  } 

  /// Sets the local time on a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - time: The DateTime object representing the time to set on the device.
  /// - Returns: Void.
  ///   - success: Invoked when the time is set successfully.
  ///   - onError: Possible errors are returned as exceptions.
  Future<void> setLocalTime(String identifier, DateTime time) async {
    try {
      // Convert the DateTime object to a timestamp (in seconds)
      final timestamp = time.millisecondsSinceEpoch / 1000;

      // Call the native method to set the local time on the Polar device
      await _channel.invokeMethod('setLocalTime', [identifier, timestamp]);
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to set local time: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error setting local time: $e');
    }
  }

  /// Performs the First Time Use setup for a Polar 360 device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  ///   - config: Configuration data for the first-time use.
  /// - Returns: Future<void>.
  ///   - success: Completes when the configuration is sent to device.
  ///   - onError: Possible errors are returned as exceptions.
  Future<void> doFirstTimeUse(
    String identifier,
    PolarFirstTimeUseConfig config,
  ) async {
    try {
      await _channel.invokeMethod('doFirstTimeUse', {
        'identifier': identifier,
        'config': config.toMap(),
      });
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to do first time use: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error doing first time use: $e');
    }
  }

  /// Checks if First Time Use setup has been completed for a Polar device.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address.
  /// - Returns: A boolean indicating if FTU is completed.
  ///   - success: Returns true if FTU is done, false otherwise.
  ///   - onError: Possible errors are returned as exceptions.
  Future<bool> isFtuDone(String identifier) async {
    try {
      final result = await _channel.invokeMethod<bool>('isFtuDone', identifier);

    // If the result is null, default to false for safety
    return result ?? false;
    } on PlatformException catch (e) {
      throw PolarBluetoothOperationException('Failed to check FTU status: ${e.message}', e);
    } catch (e) {
      throw PolarDataException('Error checking FTU status: $e');
    }
  }

  /// Check the Bluetooth bonding/pairing state for a device
  /// 
  /// Returns a map with bonding information:
  /// - isBonded: true if device is bonded/paired
  /// - bondState: "BOND_NONE", "BOND_BONDING", or "BOND_BONDED"
  /// - deviceName: name of the device (if bonded)
  /// - deviceAddress: MAC address of the device (if bonded)
  /// - error: error message (if any)
  Future<Map<String, dynamic>> getBluetoothBondingState(String identifier) async {
    try {
      final result = await _channel.invokeMethod('getBluetoothBondingState', identifier);
      
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      
      return {
        'isBonded': false,
        'bondState': 'UNKNOWN',
        'error': 'Invalid response from platform'
      };
    } on PlatformException catch (e) {
      SDKLogger.instance.error('Error checking bonding state: ${e.message}');
      return {
        'isBonded': false,
        'bondState': 'UNKNOWN',
        'error': e.message ?? 'Unknown error'
      };
    } catch (e) {
      SDKLogger.instance.error('Unexpected error checking bonding state: $e');
      return {
        'isBonded': false,
        'bondState': 'UNKNOWN',
        'error': e.toString()
      };
    }
  }

  /// Open Android Bluetooth settings
  /// 
  /// Returns true if settings were opened successfully
  /// Throws PlatformException if opening settings fails
  Future<bool> openBluetoothSettings() async {
    try {
      final result = await _channel.invokeMethod('openBluetoothSettings');
      SDKLogger.instance.info('Bluetooth settings opened successfully');
      return result == true;
    } on PlatformException catch (e) {
      SDKLogger.instance.error('Error opening Bluetooth settings: ${e.message}');
      rethrow;
    } catch (e) {
      SDKLogger.instance.error('Unexpected error opening Bluetooth settings: $e');
      rethrow;
    }
  }

  /// Get sleep data for a specific date range
  /// 
  /// Returns an empty list if no sleep data is available for the specified date range
  Future<List<PolarSleepData>> getSleep(
    String identifier,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    try {
      // Validate dates
      if (fromDate.isAfter(toDate)) {
        throw PolarDataException('fromDate must be before toDate');
      }

      if (fromDate.isAfter(DateTime.now())) {
        throw PolarDataException('fromDate cannot be in the future');
      }

      // FIXED: Don't convert to UTC, preserve local date
      // Extract just the date part in YYYY-MM-DD format using local time
      final fromDateStr = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
      
      // Log for debugging
      SDKLogger.instance.debug('getSleep: local dates from=$fromDate, to=$toDate, sending fromDateStr=$fromDateStr, toDateStr=$toDateStr');

      final response = await _channel.invokeMethod(
        'getSleep',
        [
          identifier,
          fromDateStr,
          toDateStr,
        ],
      );

      if (response == null) return [];

      if (response is String) {
        final List<dynamic> parsed = jsonDecode(response);
        return parsed
            .map((json) => PolarSleepData.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (response is List) {
        return response
            .map((data) => PolarSleepData.fromJson(Map<String, dynamic>.from(data)))
            .toList();
      }

      throw PolarDataException('Unexpected response type: ${response.runtimeType}');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarNotSupportedException('Sleep tracking not supported on device $identifier', e);
        default:
          throw PolarBluetoothOperationException('Failed to get sleep data: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error processing sleep data: $e');
    }
  }

  /// Stop sleep recording on a Polar device
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address
  /// - Returns: Future<void> that completes when sleep recording stop action has been successfully sent to device
  ///   - onError: Possible errors thrown as exceptions
  Future<void> stopSleepRecording(String identifier) async {
    try {
      await _channel.invokeMethod('stopSleepRecording', identifier);
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        default:
          throw PolarBluetoothOperationException('Failed to stop sleep recording: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error stopping sleep recording: $e');
    }
  }

  /// Get sleep recording state for a Polar device
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address
  /// - Returns: Future<bool> indicating if sleep recording is ongoing
  ///   - onError: Possible errors thrown as exceptions
  Future<bool> getSleepRecordingState(String identifier) async {
    try {
      SDKLogger.instance.debug('getSleepRecordingState: checking state for $identifier');
      final result = await _channel.invokeMethod<bool>('getSleepRecordingState', identifier);
      SDKLogger.instance.debug('getSleepRecordingState: result is $result');
      // If the result is null, default to false for safety
      return result ?? false;
    } on PlatformException catch (e) {
      SDKLogger.instance.error('getSleepRecordingState error - ${e.code}: ${e.message}');
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarNotSupportedException('Sleep state checking not supported on device $identifier', e);
        default:
          throw PolarBluetoothOperationException('Failed to get sleep recording state: ${e.message}', e);
      }
    } catch (e) {
      SDKLogger.instance.error('getSleepRecordingState unexpected error - $e');
      throw PolarDataException('Error checking sleep recording state: $e');
    }
  }

  /// Observe sleep recording state for a Polar device
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address
  /// - Returns: Stream<bool> of values indicating if sleep recording is ongoing
  ///   - onError: Possible errors thrown as exceptions
  Stream<bool> observeSleepRecordingState(String identifier) {
    SDKLogger.instance.debug('observeSleepRecordingState: starting observation for $identifier');
    final channelName = 'polar/sleep_state/$identifier';
    
    // Create a method to setup the event channel
    return _setupObservationChannel(channelName, identifier);
  }
  
 

  /// Deletes device day (YYYYMMDD) folders from the given date range from a device.
  /// The date range is inclusive. Deletes the day folder (plus all sub-folders with any contents).
  /// 
  /// Note: If some date folders don't exist, the operation will continue and delete other existing folders.
  /// The operation is considered successful as long as the device is connected and the operation is supported.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address
  ///   - fromDate: The starting date to delete date folders from
  ///   - toDate: The ending date of last date to delete folders from
  /// - Returns: Future<void> that completes when date folders are successfully deleted
  ///   - onError: Possible errors thrown as exceptions
  Future<void> deleteDeviceDateFolders(
    String identifier,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    try {
      // Validate dates
      if (fromDate.isAfter(toDate)) {
        throw PolarDataException('fromDate must be before toDate');
      }

      if (fromDate.isAfter(DateTime.now())) {
        throw PolarDataException('fromDate cannot be in the future');
      }

      // Extract just the date part in YYYY-MM-DD format using local time
      final fromDateStr = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
      
      // Log for debugging
      SDKLogger.instance.debug('deleteDeviceDateFolders: device $identifier from=$fromDateStr, to=$toDateStr');

      await _channel.invokeMethod(
        'deleteDeviceDateFolders',
        [
          identifier,
          fromDateStr,
          toDateStr,
        ],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          // For cleanup operations, missing folders are not an error - the goal is achieved
          SDKLogger.instance.debug('deleteDeviceDateFolders: folders already missing (cleanup successful)');
          return; // Treat as successful completion
        default:
          throw PolarBluetoothOperationException('Failed to delete device date folders: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error deleting device date folders: $e');
    }
  }

  /// Deletes stored data of a specific type from the device until the specified date.
  /// This is more granular than deleteDeviceDateFolders and targets specific data types.
  ///
  /// - Parameters:
  ///   - identifier: Polar device id or address
  ///   - dataType: The type of data to delete (ACTIVITY, SLEEP, DAILY_SUMMARY, etc.)
  ///   - until: Delete data until this date (inclusive)
  /// - Returns: Future<void> that completes when data is successfully deleted
  Future<void> deleteStoredDeviceData(
    String identifier,
    String dataType,
    DateTime until,
  ) async {
    try {
      // Validate date
      if (until.isAfter(DateTime.now())) {
        throw PolarDataException('until date cannot be in the future');
      }

      // Extract just the date part in YYYY-MM-DD format using local time
      final untilDateStr = '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}';
      
      // Log for debugging
      SDKLogger.instance.debug('deleteStoredDeviceData: device $identifier type=$dataType until=$untilDateStr');

      await _channel.invokeMethod(
        'deleteStoredDeviceData',
        [
          identifier,
          dataType,
          untilDateStr,
        ],
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'device_disconnected':
          throw PolarDeviceDisconnectedException('Device $identifier is not connected', e);
        case 'not_supported':
          throw PolarOperationNotSupportedException('Operation not supported by this device: ${e.message}', e);
        case 'timeout':
          throw PolarTimeoutException('Operation timed out: ${e.message}', e);
        case 'NO_SUCH_FILE_OR_DIRECTORY':
          // For cleanup operations, missing data is not an error - the goal is achieved
          SDKLogger.instance.debug('deleteStoredDeviceData: data type $dataType already missing (cleanup successful)');
          return; // Treat as successful completion
        default:
          throw PolarBluetoothOperationException('Failed to delete stored device data: ${e.message}', e);
      }
    } catch (e) {
      throw PolarDataException('Error deleting stored device data: $e');
    }
  }

  // Helper method to set up an observation channel
  Stream<bool> _setupObservationChannel(String channelName, String identifier) async* {
    try {
      // First check if the feature is available
      await _channel.invokeMethod('setupSleepStateObservation', [channelName, identifier]);
      
      yield* EventChannel(channelName)
          .receiveBroadcastStream()
          .map((dynamic event) => event as bool)
          .handleError((error) {
            SDKLogger.instance.error('Sleep state observation error: $error');
            // Transform platform errors to our custom exceptions
            if (error is PlatformException) {
              switch (error.code) {
                case 'device_disconnected':
                  throw PolarDeviceDisconnectedException('Device $identifier disconnected', error);
                case 'not_supported':
                  throw PolarNotSupportedException('Sleep state observation not supported', error);
                default:
                  throw PolarBluetoothOperationException('Sleep state observation error: ${error.message}', error);
              }
            }
            throw PolarDataException('Sleep state observation error: $error');
          });
    } catch (e) {
      SDKLogger.instance.error('_setupObservationChannel error: $e');
      throw PolarDataException('Failed to setup sleep state observation: $e');
    }
  }

  // Map<String, dynamic> _convertToStringDynamicMap(Map<Object?, Object?> map) {
  //   return map.map((key, value) {
  //     if (value is Map<Object?, Object?>) {
  //       return MapEntry(key.toString(), _convertToStringDynamicMap(value));
  //     } else if (value is List) {
  //       return MapEntry(key.toString(), value.map((e) {
  //         if (e is Map<Object?, Object?>) {
  //           return _convertToStringDynamicMap(e);
  //         }
  //         return e;
  //       }).toList());
  //     }
  //     return MapEntry(key.toString(), value);
  //   });
  // }
}
