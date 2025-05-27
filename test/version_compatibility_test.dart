import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polar SDK Version Compatibility Tests', () {
    test('SDK version matches latest official version', () {
      expect(PolarVersionCompatibility.currentSdkVersion, '6.3.0');
    });

    test('Version comparison works correctly', () {
      expect(PolarVersionCompatibility.compareVersions('6.3.0', '6.3.0'), 0);
      expect(PolarVersionCompatibility.compareVersions('6.3.0', '6.2.0'), 1);
      expect(PolarVersionCompatibility.compareVersions('6.2.0', '6.3.0'), -1);
      expect(PolarVersionCompatibility.compareVersions('6.3.0', '6.3.1'), -1);
      expect(PolarVersionCompatibility.compareVersions('6.3.1', '6.3.0'), 1);
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