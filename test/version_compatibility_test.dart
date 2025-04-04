import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polar SDK Version Compatibility Tests', () {
    test('SDK version matches latest official version', () {
      expect(PolarVersionCompatibility.currentSdkVersion, '5.17.0');
    });

    test('Version comparison works correctly', () {
      expect(PolarVersionCompatibility.compareVersions('5.17.0', '5.17.0'), 0);
      expect(PolarVersionCompatibility.compareVersions('5.17.0', '5.16.0'), 1);
      expect(PolarVersionCompatibility.compareVersions('5.16.0', '5.17.0'), -1);
      expect(PolarVersionCompatibility.compareVersions('5.17.0', '5.17.1'), -1);
      expect(PolarVersionCompatibility.compareVersions('5.17.1', '5.17.0'), 1);
    });

    test('Feature compatibility checks work correctly', () {
      // These should always be true with current version
      expect(PolarVersionCompatibility.shouldUseNewStreamingApi(), true);
      expect(PolarVersionCompatibility.supportsTemperatureSensor(), true);
    });

    test('Version format is valid', () {
      // Verify version string follows semantic versioning (major.minor.patch)
      const version = PolarVersionCompatibility.currentSdkVersion;
      final parts = version.split('.');
      expect(parts.length, 3);
      expect(parts.every((part) => int.tryParse(part) != null), true);
    });
  });
} 