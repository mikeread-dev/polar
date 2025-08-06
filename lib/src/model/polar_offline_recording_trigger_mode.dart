import 'dart:io';

/// Polar offline recording trigger mode. Offline recording trigger can be used to 
/// start the offline recording automatically in device, based on selected trigger mode.
enum PolarOfflineRecordingTriggerMode {
  /// Trigger is disabled
  triggerDisabled,
  
  /// Recording starts automatically on system start (after battery charge)
  triggerSystemStart,
  
  /// Recording starts automatically when exercise begins
  triggerExerciseStart;

  /// Create a [PolarOfflineRecordingTriggerMode] from json
  static PolarOfflineRecordingTriggerMode fromJson(dynamic json) {
    if (Platform.isIOS) {
      return PolarOfflineRecordingTriggerMode.values[json as int];
    } else {
      // This is Android
      switch (json as String) {
        case 'TRIGGER_DISABLED':
          return PolarOfflineRecordingTriggerMode.triggerDisabled;
        case 'TRIGGER_SYSTEM_START':
          return PolarOfflineRecordingTriggerMode.triggerSystemStart;
        case 'TRIGGER_EXERCISE_START':
          return PolarOfflineRecordingTriggerMode.triggerExerciseStart;
        default:
          throw ArgumentError('Unknown trigger mode: $json');
      }
    }
  }

  /// Convert a [PolarOfflineRecordingTriggerMode] to json
  dynamic toJson() {
    // Use consistent camelCase strings for both platforms
    switch (this) {
      case PolarOfflineRecordingTriggerMode.triggerDisabled:
        return 'triggerDisabled';
      case PolarOfflineRecordingTriggerMode.triggerSystemStart:
        return 'triggerSystemStart';
      case PolarOfflineRecordingTriggerMode.triggerExerciseStart:
        return 'triggerExerciseStart';
    }
  }
}