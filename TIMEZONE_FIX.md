# Polar SDK Timezone Fix

This document explains the fix for timezone-related issues in the Polar Flutter plugin, particularly affecting UTC+10 timezone users.

## Issues Fixed

1. **`getSleep` Timezone Issue**: Users in UTC+10 timezone weren't seeing sleep data until later in the day (around 11:30 AM local time).

2. **`stopSleepRecording` Error 106**: Users in UTC+10 timezone consistently encountered error 106 when trying to stop sleep recording.

## Fix Implementation

### getSleep Timezone Fix

The issue was that `LocalDate` in the Polar SDK has no timezone information. When users in UTC+10 queried for "today's" data in their morning, it didn't match the device's interpretation of the current date.

**Fix**: We modified the Flutter code to convert all dates to UTC before extracting just the date part:

```dart
// Original code
final fromDateStr = fromDate.toIso8601String().split('T')[0];
final toDateStr = toDate.toIso8601String().split('T')[0];

// Fixed code
final fromDateUtc = fromDate.toUtc();
final toDateUtc = toDate.toUtc();
final fromDateStr = fromDateUtc.toIso8601String().split('T')[0];
final toDateStr = toDateUtc.toIso8601String().split('T')[0];
```

### stopSleepRecording Error 106 Fix

The Error 106 occurs in UTC+10 timezone because the device may be in a state where stopping sleep recording isn't allowed at that particular time.

**Fix**: We added two APIs from the native Polar SDK:

1. `getSleepRecordingState()` - Check if sleep recording is active before attempting to stop it
2. `observeSleepRecordingState()` - Monitor sleep recording state changes

## Testing the Fix

We've added a special test file that simulates the UTC+10 timezone:

```
test/timezone_test.dart
```

And a shell script to run the tests with a simulated UTC+10 timezone:

```
./run_timezone_tests.sh
```

### How to Test Manually

For manual testing, you should:

1. **For `getSleep`**:
   - In a UTC+10 timezone environment, call `getSleep()` in the morning (before noon)
   - Verify that sleep data from the previous night is retrieved correctly

2. **For `stopSleepRecording`**:
   - In a UTC+10 timezone environment, first check if recording is active:
     ```dart
     bool isRecording = await polar.getSleepRecordingState(deviceId);
     ```
   - Only stop recording if it's active:
     ```dart
     if (isRecording) {
       await polar.stopSleepRecording(deviceId);
     }
     ```

## Best Practices

1. **Always Check Recording State First**:
   ```dart
   bool isRecording = await polar.getSleepRecordingState(deviceId);
   if (isRecording) {
     await polar.stopSleepRecording(deviceId);
   }
   ```

2. **Observe Recording State Changes**:
   ```dart
   polar.observeSleepRecordingState(deviceId).listen((isRecording) {
     if (!isRecording) {
       // Sleep recording has ended naturally
       fetchSleepData();
     }
   });
   ```

3. **Use UTC for Date Range Queries**:
   The fix handles this automatically, but keep in mind that dates are converted to UTC before being sent to the Polar SDK.

## Debugging

For both iOS and Android implementations, we've added extensive logging to help diagnose any future timezone-related issues:

- When dates are converted to UTC
- What specific dates are sent to the native SDK
- How many sleep records are returned
- The actual dates of the returned sleep records
- Current device time before stopping sleep recording
- Success or failure of stop sleep recording attempts

These logs will help identify if there are any remaining timezone-related issues. 