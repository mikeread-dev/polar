import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polar SDK Feature Tests', () {

    setUp(() {
    });

    test('SDK Feature mapping works correctly for all features', () {
      // Test HR feature
      expect(
        PolarSdkFeature.hr.toJson(),
        Platform.isIOS ? 0 : 'FEATURE_HR',
      );

      // Test Device Info feature
      expect(
        PolarSdkFeature.deviceInfo.toJson(),
        Platform.isIOS ? 1 : 'FEATURE_DEVICE_INFO',
      );

      // Test Battery Info feature
      expect(
        PolarSdkFeature.batteryInfo.toJson(),
        Platform.isIOS ? 2 : 'FEATURE_BATTERY_INFO',
      );

      // Test Online Streaming feature
      expect(
        PolarSdkFeature.onlineStreaming.toJson(),
        Platform.isIOS ? 3 : 'FEATURE_POLAR_ONLINE_STREAMING',
      );

      // Test Offline Recording feature
      expect(
        PolarSdkFeature.offlineRecording.toJson(),
        Platform.isIOS ? 4 : 'FEATURE_POLAR_OFFLINE_RECORDING',
      );

      // Test H10 Exercise Recording feature
      expect(
        PolarSdkFeature.h10ExerciseRecording.toJson(),
        Platform.isIOS ? 5 : 'FEATURE_POLAR_H10_EXERCISE_RECORDING',
      );

      // Test Device Time Setup feature
      expect(
        PolarSdkFeature.deviceTimeSetup.toJson(),
        Platform.isIOS ? 6 : 'FEATURE_POLAR_DEVICE_TIME_SETUP',
      );

      // Test SDK Mode feature
      expect(
        PolarSdkFeature.sdkMode.toJson(),
        Platform.isIOS ? 7 : 'FEATURE_POLAR_SDK_MODE',
      );

      // Test LED Animation feature
      expect(
        PolarSdkFeature.ledAnimation.toJson(),
        Platform.isIOS ? 8 : 'FEATURE_POLAR_LED_ANIMATION',
      );

      // Test Sleep feature
      expect(
        PolarSdkFeature.sleep.toJson(),
        Platform.isIOS ? 9 : 'FEATURE_POLAR_SLEEP',
      );
    });

    test('SDK Feature deserialization works correctly', () {
      if (Platform.isIOS) {
        // Test deserialization from numeric values (iOS)
        expect(PolarSdkFeature.fromJson(0), PolarSdkFeature.hr);
        expect(PolarSdkFeature.fromJson(1), PolarSdkFeature.deviceInfo);
        expect(PolarSdkFeature.fromJson(2), PolarSdkFeature.batteryInfo);
        expect(PolarSdkFeature.fromJson(3), PolarSdkFeature.onlineStreaming);
        expect(PolarSdkFeature.fromJson(4), PolarSdkFeature.offlineRecording);
        expect(PolarSdkFeature.fromJson(5), PolarSdkFeature.h10ExerciseRecording);
        expect(PolarSdkFeature.fromJson(6), PolarSdkFeature.deviceTimeSetup);
        expect(PolarSdkFeature.fromJson(7), PolarSdkFeature.sdkMode);
        expect(PolarSdkFeature.fromJson(8), PolarSdkFeature.ledAnimation);
        expect(PolarSdkFeature.fromJson(9), PolarSdkFeature.sleep);
      } else {
        // Test deserialization from string values (Android)
        expect(PolarSdkFeature.fromJson('FEATURE_HR'), PolarSdkFeature.hr);
        expect(PolarSdkFeature.fromJson('FEATURE_DEVICE_INFO'), PolarSdkFeature.deviceInfo);
        expect(PolarSdkFeature.fromJson('FEATURE_BATTERY_INFO'), PolarSdkFeature.batteryInfo);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_ONLINE_STREAMING'), PolarSdkFeature.onlineStreaming);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_OFFLINE_RECORDING'), PolarSdkFeature.offlineRecording);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_H10_EXERCISE_RECORDING'), PolarSdkFeature.h10ExerciseRecording);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_DEVICE_TIME_SETUP'), PolarSdkFeature.deviceTimeSetup);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_SDK_MODE'), PolarSdkFeature.sdkMode);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_LED_ANIMATION'), PolarSdkFeature.ledAnimation);
        expect(PolarSdkFeature.fromJson('FEATURE_POLAR_SLEEP'), PolarSdkFeature.sleep);
      }
    });

    test('SDK Feature round-trip serialization works correctly', () {
      // Test that serializing and deserializing each feature returns the same value
      for (final feature in PolarSdkFeature.values) {
        final serialized = feature.toJson();
        final deserialized = PolarSdkFeature.fromJson(serialized);
        expect(deserialized, feature);
      }
    });
  });
}
