import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polar SDK Feature Tests', () {
    late Polar polar;

    setUp(() {
      polar = Polar();
    });

    test('SDK Feature mapping works correctly', () {
      expect(
        PolarSdkFeature.hr.toJson(),
        Platform.isIOS ? 0 : 'FEATURE_HR',
      );
    });

    // Add more tests
  });
}
