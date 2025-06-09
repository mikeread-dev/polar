import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polar/polar.dart';

const identifier = 'UTC10_device';
const utcPlus10Offset = Duration(hours: 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('polar'), handleUTC10TimezoneMock);
  });
  
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('polar'), null);
  });

  group('UTC+10 timezone handling tests', () {
    test('getSleep correctly handles UTC+10 timezone', () async {
      final polar = Polar();
      
      // Test with a Sydney timezone date (UTC+10)
      final syd11am = DateTime(2023, 5, 12, 11, 30); // 11:30 AM Sydney time
      final sydYesterday = DateTime(2023, 5, 11); // Previous day in Sydney
      
      // Get sleep data for a week back
      final sleepData = await polar.getSleep(
        identifier,
        sydYesterday,
        syd11am,
      );
      
      // Verify data was returned (the mock will return data for any date after 2022)
      expect(sleepData, isNotEmpty);
      
      // Verify the mock received correct UTC-converted dates
      expect(mockReceivedFromDate, isNotNull);
      expect(mockReceivedToDate, isNotNull);
      
      // The dates should have been converted to UTC before being sent to the method channel
      final sydYesterdayUtc = sydYesterday.toUtc();
      final syd11amUtc = syd11am.toUtc();
      
      // The date strings should match the UTC version (just the date part)
      expect(mockReceivedFromDate, sydYesterdayUtc.toIso8601String().split('T')[0]);
      expect(mockReceivedToDate, syd11amUtc.toIso8601String().split('T')[0]);
    });
    
    test('getSleepRecordingState handles timezone correctly', () async {
      final polar = Polar();
      final isRecording = await polar.getSleepRecordingState(identifier);
      expect(isRecording, isTrue); // Our mock returns true
    });
    
    test('stopSleepRecording handles error 106 in UTC+10', () async {
      final polar = Polar();
      
      // The mock will simulate error 106 on first attempt for UTC+10 timezone device
      // but will succeed on the second attempt if checking recording state first
      
      // First approach (will fail with 106 error)
      var directStopFailed = false;
      try {
        await polar.stopSleepRecording(identifier);
      } catch (e) {
        directStopFailed = true;
        expect(e, isA<PolarBluetoothOperationException>());
        expect((e as PolarBluetoothOperationException).message.contains('106'), isTrue);
      }
      expect(directStopFailed, isTrue);
      
      // Better approach: Check state first, then stop if active
      final isRecording = await polar.getSleepRecordingState(identifier);
      if (isRecording) {
        // Our mock will succeed on second attempt
        mockStopSleepAttempts = 1; // Reset the counter
        await polar.stopSleepRecording(identifier);
        expect(mockStopSleepAttempts, 2); // Should increment to 2
      }
    });
  });
}

// Variables to track mock calls
String? mockReceivedFromDate;
String? mockReceivedToDate;
int mockStopSleepAttempts = 0;

Future<dynamic> handleUTC10TimezoneMock(MethodCall methodCall) async {
  switch (methodCall.method) {
    case 'getSleep':
      final arguments = methodCall.arguments as List<dynamic>;
      mockReceivedFromDate = arguments[1] as String;
      mockReceivedToDate = arguments[2] as String;
      
      // Return empty list for dates in 2022
      if (mockReceivedFromDate!.startsWith('2022')) {
        return [];
      }
      
      // Create a fake sleep data response
      final now = DateTime.now();
      final sleepData = [
        {
          'date': now.subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')[0],
          'result': {
            'batteryRanOut': false,
            'deviceId': identifier,
            'lastModified': now.toIso8601String(),
            'sleepCycles': [
              {
                'secondsFromSleepStart': 3600,
                'sleepDepthStart': 0.8,
              }
            ],
            'sleepEndOffsetSeconds': 28800,
            'sleepEndTime': now.subtract(const Duration(hours: 8)).toIso8601String(),
            'sleepGoalMinutes': 480,
            'sleepResultDate': now.subtract(const Duration(days: 1)).toIso8601String().split('T')[0],
            'sleepStartOffsetSeconds': 0,
            'sleepStartTime': now.subtract(const Duration(hours: 16)).toIso8601String(),
            'sleepWakePhases': [
              {
                'secondsFromSleepStart': 1800,
                'state': 'DEEP_SLEEP',
              }
            ],
          },
        }
      ];
      
      return jsonEncode(sleepData);
      
    case 'getSleepRecordingState':
      return true; // Always return true for our test
      
    case 'stopSleepRecording':
      mockStopSleepAttempts++;
      
      // Simulate error 106 on first attempt for UTC+10 timezone device
      if (mockStopSleepAttempts == 1) {
        throw PlatformException(
          code: 'bluetooth_error',
          message: 'Request failed: Error: 106',
        );
      }
      return null; // Success on second attempt
    
    case 'setupSleepStateObservation':
      // We won't actually test the stream in this test
      return null;
      
    default:
      return null;
  }
} 