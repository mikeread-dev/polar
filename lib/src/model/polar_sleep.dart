// Remove the ignore directive since the file has proper documentation

import 'package:json_annotation/json_annotation.dart';

part 'polar_sleep.g.dart';

/// Represents sleep data for a specific date
@JsonSerializable()
class PolarSleepData {
  /// The date for which sleep data was recorded
  @JsonKey(name: 'date')
  final DateTime? date;
  
  /// Detailed analysis of sleep patterns and stages
  @JsonKey(name: 'result')
  final SleepAnalysisResult? analysis;

  /// Creates a new [PolarSleepData] instance
  /// 
  /// Parameters:
  /// - [date]: The date for which sleep data was recorded (will be converted to UTC)
  /// - [analysis]: Detailed analysis of sleep patterns and stages
  PolarSleepData({
    this.date,
    this.analysis,
  });

  // Ignore as fromJson is obvious
  // ignore: public_member_api_docs
  factory PolarSleepData.fromJson(Map<String, dynamic> json) =>
      _$PolarSleepDataFromJson(json);

// Ignore as fromJson is obvious
  // ignore: public_member_api_docs
  Map<String, dynamic> toJson() => _$PolarSleepDataToJson(this);
}

/// Contains the results of sleep analysis including total sleep duration,
/// continuous sleep duration, and detailed sleep intervals with sleep stages
@JsonSerializable()
class SleepAnalysisResult {
  /// Indicates whether the device's battery ran out during sleep tracking
  final bool? batteryRanOut;

  /// The unique identifier of the Polar device
  final String? deviceId;

  /// The timestamp when this sleep data was last modified
  final DateTime? lastModified;

  /// List of sleep cycles detected during the sleep period
  final List<SleepCycle>? sleepCycles;

  /// Number of seconds from the reference point to sleep end time
  final int? sleepEndOffsetSeconds;

  /// The time when sleep ended
  final DateTime? sleepEndTime;

  /// The user's sleep goal in minutes
  final int? sleepGoalMinutes;

  /// The date for which this sleep result was recorded
  final DateTime? sleepResultDate;

  /// Number of seconds from the reference point to sleep start time
  final int? sleepStartOffsetSeconds;

  /// The time when sleep started
  final DateTime? sleepStartTime;

  /// List of sleep and wake phases detected during the sleep period
  final List<SleepWakePhase>? sleepWakePhases;

  /// Creates a new [SleepAnalysisResult] instance
  /// 
  /// Contains detailed sleep analysis data including timing, phases, and device information
  /// All DateTime values are converted to UTC
  SleepAnalysisResult({
    this.batteryRanOut,
    this.deviceId,
    this.lastModified,
    this.sleepCycles,
    this.sleepEndOffsetSeconds,
    this.sleepEndTime,
    this.sleepGoalMinutes,
    this.sleepResultDate,
    this.sleepStartOffsetSeconds,
    this.sleepStartTime,
    this.sleepWakePhases,
  });

  /// Creates a [SleepAnalysisResult] from a JSON map
  /// 
  /// Parameters:
  /// - [json]: A map containing the sleep analysis data
  /// 
  /// Returns a new [SleepAnalysisResult] instance with the parsed JSON data
  /// All DateTime values are converted to UTC
  factory SleepAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SleepAnalysisResult(
      batteryRanOut: json['batteryRanOut'] as bool?,
      deviceId: json['deviceId'] as String?,
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
      sleepCycles: (json['sleepCycles'] as List<dynamic>?)
          ?.map((e) => SleepCycle.fromJson(e as Map<String, dynamic>))
          .toList(),
      sleepEndOffsetSeconds: json['sleepEndOffsetSeconds'] as int?,
      sleepEndTime: json['sleepEndTime'] == null
          ? null
          : DateTime.parse(json['sleepEndTime'] as String),
      sleepGoalMinutes: json['sleepGoalMinutes'] as int?,
      sleepResultDate: json['sleepResultDate'] == null
          ? null
          : DateTime.parse(json['sleepResultDate'] as String),
      sleepStartOffsetSeconds: json['sleepStartOffsetSeconds'] as int?,
      sleepStartTime: json['sleepStartTime'] == null
          ? null
          : DateTime.parse(json['sleepStartTime'] as String),
      sleepWakePhases: (json['sleepWakePhases'] as List<dynamic>?)
          ?.map((e) => SleepWakePhase.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts the [SleepAnalysisResult] instance to a JSON map
  /// 
  /// Returns a [Map] containing the sleep analysis data in a JSON-compatible format
  Map<String, dynamic> toJson() => {
        'batteryRanOut': batteryRanOut,
        'deviceId': deviceId,
        'lastModified': lastModified?.toIso8601String(),
        'sleepCycles': sleepCycles?.map((e) => e.toJson()).toList(),
        'sleepEndOffsetSeconds': sleepEndOffsetSeconds,
        'sleepEndTime': sleepEndTime?.toIso8601String(),
        'sleepGoalMinutes': sleepGoalMinutes,
        'sleepResultDate': sleepResultDate?.toIso8601String(),
        'sleepStartOffsetSeconds': sleepStartOffsetSeconds,
        'sleepStartTime': sleepStartTime?.toIso8601String(),
        'sleepWakePhases': sleepWakePhases?.map((e) => e.toJson()).toList(),
      };
}

/// Represents a single sleep cycle with timing and depth information
/// 
/// A sleep cycle contains information about when it occurred relative to sleep start
/// and how deep the sleep was at the beginning of the cycle
@JsonSerializable()
class SleepCycle {
  /// Number of seconds elapsed since the start of sleep
  final int secondsFromSleepStart;

  /// The depth of sleep at the beginning of this cycle
  /// 
  /// Higher values indicate deeper sleep states
  final double sleepDepthStart;

  /// Creates a new [SleepCycle] instance
  /// 
  /// Parameters:
  /// - [secondsFromSleepStart]: Number of seconds from the start of sleep
  /// - [sleepDepthStart]: The depth of sleep at the start of this cycle
  SleepCycle({
    required this.secondsFromSleepStart,
    required this.sleepDepthStart,
  });

  /// Creates a [SleepCycle] instance from a JSON map
  factory SleepCycle.fromJson(Map<String, dynamic> json) =>
      _$SleepCycleFromJson(json);

  /// Converts the [SleepCycle] instance to a JSON map
  Map<String, dynamic> toJson() => _$SleepCycleToJson(this);
}

/// Represents a phase of sleep or wakefulness during the sleep period
/// 
/// Each phase contains information about when it occurred relative to sleep start
/// and the state of sleep/wakefulness during that phase
@JsonSerializable()
class SleepWakePhase {
  /// Number of seconds elapsed since the start of sleep when this phase began
  final int secondsFromSleepStart;

  /// The state of sleep or wakefulness during this phase
  /// 
  /// Can be one of the sleep stages defined in [PolarSleepStage]
  final String state;

  /// Creates a new [SleepWakePhase] instance
  /// 
  /// Parameters:
  /// - [secondsFromSleepStart]: Number of seconds from the start of sleep
  /// - [state]: The sleep state during this phase
  SleepWakePhase({
    required this.secondsFromSleepStart,
    required this.state,
  });

  /// Creates a [SleepWakePhase] instance from a JSON map
  factory SleepWakePhase.fromJson(Map<String, dynamic> json) =>
      _$SleepWakePhaseFromJson(json);

  /// Converts the [SleepWakePhase] instance to a JSON map
  Map<String, dynamic> toJson() => _$SleepWakePhaseToJson(this);
}
