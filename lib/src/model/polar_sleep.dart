import 'package:json_annotation/json_annotation.dart';
import 'package:polar/src/model/converters.dart';
import 'package:polar/src/model/polar_sleep_stage.dart';

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

  PolarSleepData({
    this.date,
    this.analysis,
  });

  factory PolarSleepData.fromJson(Map<String, dynamic> json) {
    return PolarSleepData(
      date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
      analysis: json['result'] == null
          ? null
          : SleepAnalysisResult.fromJson(json['result'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date?.toIso8601String(),
        'result': analysis?.toJson(),
      };
}

/// Contains the results of sleep analysis including total sleep duration,
/// continuous sleep duration, and detailed sleep intervals with sleep stages
@JsonSerializable()
class SleepAnalysisResult {
  final bool? batteryRanOut;
  final String? deviceId;
  final DateTime? lastModified;
  final List<SleepCycle>? sleepCycles;
  final int? sleepEndOffsetSeconds;
  final DateTime? sleepEndTime;
  final int? sleepGoalMinutes;
  final DateTime? sleepResultDate;
  final int? sleepStartOffsetSeconds;
  final DateTime? sleepStartTime;
  final List<SleepWakePhase>? sleepWakePhases;

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

@JsonSerializable()
class SleepCycle {
  final int secondsFromSleepStart;
  final double sleepDepthStart;

  SleepCycle({
    required this.secondsFromSleepStart,
    required this.sleepDepthStart,
  });

  factory SleepCycle.fromJson(Map<String, dynamic> json) =>
      _$SleepCycleFromJson(json);

  Map<String, dynamic> toJson() => _$SleepCycleToJson(this);
}

@JsonSerializable()
class SleepWakePhase {
  final int secondsFromSleepStart;
  final String state;

  SleepWakePhase({
    required this.secondsFromSleepStart,
    required this.state,
  });

  factory SleepWakePhase.fromJson(Map<String, dynamic> json) =>
      _$SleepWakePhaseFromJson(json);

  Map<String, dynamic> toJson() => _$SleepWakePhaseToJson(this);
}
