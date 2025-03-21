import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polar Data Model Tests', () {
    test('PolarDataType enum conversion works correctly', () {
      expect(PolarDataType.ecg.toJson(), Platform.isIOS ? 0 : 'ECG');
      expect(PolarDataType.acc.toJson(), Platform.isIOS ? 1 : 'ACC');
      expect(PolarDataType.ppi.toJson(), Platform.isIOS ? 3 : 'PPI');
      
      // Test that the data types are correctly mapped
      final dataTypes = [
        PolarDataType.ecg,
        PolarDataType.acc,
        PolarDataType.ppg,
        PolarDataType.ppi,
        PolarDataType.gyro,
        PolarDataType.magnetometer,
      ];
      
      for (final type in dataTypes) {
        expect(type.toJson(), isNotNull);
      }
    });
    
    test('PolarPpiSample serialization/deserialization works correctly', () {
      final timestamp = DateTime.now();
      final sample = PolarPpiSample(
        timeStamp: timestamp,
        ppi: 1000,
        errorEstimate: 5,
        hr: 60,
        blockerBit: false,
        skinContactStatus: true,
        skinContactSupported: true,
      );
      
      final json = sample.toJson();
      expect(json['ppi'], 1000);
      expect(json['errorEstimate'], 5);
      expect(json['hr'], 60);
      
      // Test round-trip serialization
      final decoded = PolarPpiSample.fromJson(json);
      expect(decoded.ppi, 1000);
      expect(decoded.errorEstimate, 5);
      expect(decoded.hr, 60);
      expect(decoded.blockerBit, false);
      expect(decoded.skinContactStatus, true);
      expect(decoded.skinContactSupported, true);
    });
    
    test('PolarStreamingData with PPI samples works correctly', () {
      final timestamp = DateTime.now();
      final samples = [
        PolarPpiSample(
          timeStamp: timestamp,
          ppi: 1000,
          errorEstimate: 5,
          hr: 60,
          blockerBit: false,
          skinContactStatus: true,
          skinContactSupported: true,
        ),
        PolarPpiSample(
          timeStamp: timestamp.add(const Duration(seconds: 1)),
          ppi: 1050,
          errorEstimate: 8,
          hr: 62,
          blockerBit: false,
          skinContactStatus: true,
          skinContactSupported: true,
        ),
      ];
      
      final ppiData = PolarPpiData(samples: samples);
      final json = ppiData.toJson();
      
      expect(json['samples'], isA<List>());
      expect(json['samples'].length, 2);
      
      final decoded = PolarPpiData.fromJson(json);
      expect(decoded.samples.length, 2);
      expect(decoded.samples[0].ppi, 1000);
      expect(decoded.samples[1].ppi, 1050);
      expect(decoded.samples[0].errorEstimate, 5);
      expect(decoded.samples[1].errorEstimate, 8);
    });
    
    test('PolarAccSample serialization/deserialization works correctly', () {
      final timestamp = DateTime.now();
      final sample = PolarAccSample(
        timeStamp: timestamp,
        x: 100,
        y: 200,
        z: 300,
      );
      
      final json = sample.toJson();
      final decoded = PolarAccSample.fromJson(json);
      
      expect(decoded.x, 100);
      expect(decoded.y, 200);
      expect(decoded.z, 300);
    });
  });
} 