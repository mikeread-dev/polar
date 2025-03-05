import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';
import 'package:polar/src/model/polar_offline_recording_data.dart';

import 'tests.dart';

const identifier = 'asdf';
final info = jsonEncode(
  PolarDeviceInfo(
    deviceId: identifier,
    address: '',
    rssi: 0,
    name: '',
    isConnectable: true,
  ),
);
const channel = MethodChannel('polar');
const searchChannel = EventChannel('polar/search');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handleMethodCall);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(searchChannel, SearchHandler());
  });

  testSearch(identifier);
  testConnection(identifier);
  testBasicData(identifier);
  testBleSdkFeatures(identifier, features: PolarSdkFeature.values.toSet());
  testStreaming(identifier, features: PolarDataType.values.toSet());
  testRecording(identifier, wait: false);
  testSdkMode(identifier);
  testMisc(identifier, isVerity: true);
  testAvailableOfflineRecordingDataTypes(identifier);
  testOfflineRecording(identifier);
  testSleepData(identifier);
}

Future<void> invoke(String method, [dynamic arguments]) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    null,
  );
}

void executeLater<T>(FutureOr<T> Function() computation) {
  Future.delayed(Duration.zero, computation);
}

final exercises = <PolarExerciseEntry>[];
var recording = false;
var exerciseId = '';
var sdkModeEnabled = false;
final offlineRecordings = <PolarOfflineRecordingEntry>[];
var diskSpace = [14416896, 14369729];

Future<dynamic> handleMethodCall(MethodCall methodCall) async {
  print('Method called: ${methodCall.method}');
  print('Arguments: ${methodCall.arguments}');
  
  switch (methodCall.method) {
    case 'connectToDevice':
      executeLater(() async {
        await invoke('deviceConnecting', info);
        await invoke('deviceConnected', info);
        await invoke('disInformationReceived', [identifier, '', '']);
        await invoke('batteryLevelReceived', [identifier, 100]);
        for (final feature in PolarSdkFeature.values) {
          await invoke('sdkFeatureReady', [identifier, feature.toJson()]);
        }
      });
      return null;
    case 'disconnectFromDevice':
      executeLater(() => invoke('deviceDisconnected', [info, false]));
      return null;
    case 'getAvailableOnlineStreamDataTypes':
      return jsonEncode(PolarDataType.values.map((e) => e.toJson()).toList());
    case 'requestStreamSettings':
      return jsonEncode(PolarSensorSetting({}));
    case 'createStreamingChannel':
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
              EventChannel(methodCall.arguments[0] as String),
              StreamingHandler(PolarDataType.fromJson(methodCall.arguments[2])),
          );
      return null;
    case 'startRecording':
      recording = true;
      exerciseId = methodCall.arguments[1];
      return null;
    case 'stopRecording':
      recording = false;
      exercises.add(
        PolarExerciseEntry(path: '', date: DateTime.now(), entryId: exerciseId),
      );
      return null;
    case 'requestRecordingStatus':
      return [recording, exerciseId];
    case 'getOfflineRecordingStatus':
      return [PolarDataType.acc.toJson()];  // Return only ACC as the active recording
    case 'listExercises':
      return exercises.map(jsonEncode).toList();
    case 'fetchExercise':
      return jsonEncode({
        'recordingInterval': 0,
        'hrSamples': [0],
      });
    case 'removeExercise':
      exercises.clear();
      return null;
    case 'setLedConfig':
      return null;
    case 'enableSdkMode':
      sdkModeEnabled = true;
      return null;
    case 'disableSdkMode':
      sdkModeEnabled = false;
      return null;
    case 'isSdkModeEnabled':
      return sdkModeEnabled;
    case 'doFactoryReset':
      return null;
    case 'getAvailableOfflineRecordingDataTypes':
      return jsonEncode(PolarDataType.values.map((e) => e.toJson()).toList());
    case 'requestOfflineRecordingSettings':
      return jsonEncode(PolarSensorSetting({}));
    case 'startOfflineRecording':
      offlineRecordings.add(
        PolarOfflineRecordingEntry(
          date: DateTime.now(),
          path: '',
          size: 1,
          type: PolarDataType.acc,
        ),
      );
      return null;
    case 'stopOfflineRecording':
      diskSpace = [14416896, 14362624];
      return null;
    case 'listOfflineRecordings':
      return offlineRecordings.map((entry) => jsonEncode(entry.toJson())).toList();
    case 'getOfflineAccRecord':
      return offlineRecordings.isNotEmpty
          ? AccOfflineRecording(
              data: PolarStreamingData<PolarAccSample>(
                samples: [
                  PolarAccSample(timeStamp: DateTime.now(), x: 1, y: 1, z: 1),
                ],
              ),
              startTime: DateTime.now(),
              settings: PolarSensorSetting({}),
            )
          : null;
    case 'getOfflinePpiRecord':
      return null;
    case 'getOfflinePpgRecord':
      return null;
    case 'getDiskSpace':
      return diskSpace;
    case 'removeOfflineRecord':
      diskSpace = [14416896, 14369729];
      return offlineRecordings.clear();
    case 'getOfflineRecord':
      final arguments = methodCall.arguments as List<dynamic>;
      final entryJsonString = arguments[1] as String;
      final entry = PolarOfflineRecordingEntry.fromJson(jsonDecode(entryJsonString));
      
      if (entry.type == PolarDataType.acc) {
        final now = DateTime.now();
        final accData = {
          'data': {
            'type': 'acc',
            'samples': [
              {
                'timeStamp': now.millisecondsSinceEpoch,
                'x': 1,
                'y': 1,
                'z': 1
              }
            ]
          },
          'startTime': {
            'year': now.year,
            'month': now.month - 1,  // Month is 0-based in the converter
            'dayOfMonth': now.day,
            'hourOfDay': now.hour,
            'minute': now.minute,
            'second': now.second,
          },
          'settings': {
            'settings': {}
          }
        };
        return jsonEncode(accData);
      } else if (entry.type == PolarDataType.ppi) {
        return null;
      }
      return null;
    case 'getSleep':
      final arguments = methodCall.arguments as List<dynamic>;
      final fromDateStr = arguments[1] as String;
      
      // Return empty list for dates in 2022
      if (fromDateStr.startsWith('2022')) {
        return [];
      }
      
      final now = DateTime.now();
      
      return [
        {
          'date': now.subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')[0],
          'analysis': {
            'sleepDuration': 28800000,
            'continuousSleepDuration': 25200000,
            'sleepIntervals': [
              {
                'startTime': now.subtract(const Duration(hours: 8)).toIso8601String(),
                'endTime': now.subtract(const Duration(hours: 7)).toIso8601String(),
                'sleepStage': 'DEEP_SLEEP'
              }
            ]
          }
        }
      ];
    default:
      print('Unimplemented method: ${methodCall.method}');
      throw UnimplementedError();
  }
}

class SearchHandler extends MockStreamHandler {
  @override
  void onListen(dynamic arguments, MockStreamHandlerEventSink events) {
    events.success(info);
  }

  @override
  void onCancel(dynamic arguments) {}
}

class StreamingHandler extends MockStreamHandler {
  final PolarDataType type;

  StreamingHandler(this.type);

  @override
  void onListen(dynamic arguments, MockStreamHandlerEventSink events) {
    final PolarStreamingData data;
    switch (type) {
      case PolarDataType.ecg:
        data = PolarEcgData(
          samples: [PolarEcgSample(timeStamp: DateTime.now(), voltage: 0)],
        );
      case PolarDataType.acc:
        data = PolarAccData(
          samples: [
            PolarAccSample(timeStamp: DateTime.now(), x: 0, y: 0, z: 0),
          ],
        );
      case PolarDataType.ppg:
        data = PolarPpgData(
          type: PpgDataType.ppg3_ambient1,
          samples: [
            PolarPpgSample(timeStamp: DateTime.now(), channelSamples: []),
          ],
        );
      case PolarDataType.ppi:
        data = PolarPpiData(
          samples: [
            PolarPpiSample(
              ppi: 0,
              errorEstimate: 0,
              hr: 0,
              blockerBit: false,
              skinContactStatus: false,
              skinContactSupported: false,
            ),
          ],
        );
      case PolarDataType.gyro:
        data = PolarGyroData(
          samples: [
            PolarGyroSample(timeStamp: DateTime.now(), x: 0, y: 0, z: 0),
          ],
        );
      case PolarDataType.magnetometer:
        data = PolarMagnetometerData(
          samples: [
            PolarMagnetometerSample(
              timeStamp: DateTime.now(),
              x: 0,
              y: 0,
              z: 0,
            ),
          ],
        );
      case PolarDataType.hr:
        data = PolarHrData(
          samples: [
            PolarHrSample(
              hr: 0,
              rrsMs: [],
              contactStatus: false,
              contactStatusSupported: false,
            ),
          ],
        );
      case PolarDataType.temperature:
        data = PolarTemperatureData(
          samples: [
            PolarTemperatureSample(
              timeStamp: DateTime.now(),
              temperature: 0,
            ),
          ],
        );
      case PolarDataType.pressure:
        data = PolarPressureData(
          samples: [
            PolarPressureSample(
              timeStamp: DateTime.now(),
              pressure: 0,
            ),
          ],
        );
    }

    events.success(jsonEncode(data));
  }

  @override
  void onCancel(dynamic arguments) {}
}
