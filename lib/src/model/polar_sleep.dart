import 'package:json_annotation/json_annotation.dart';
import 'package:polar/src/model/converters.dart';
import 'package:polar/src/model/polar_sleep_stage.dart';

part 'polar_sleep.g.dart';

/// Represents sleep data for a specific date
@JsonSerializable()
class PolarSleepData {
  /// The date for which sleep data was recorded
  final DateTime date;
  
  /// Detailed analysis of sleep patterns and stages
  final SleepAnalysisResult analysis;

  PolarSleepData({
    required this.date,
    required this.analysis,
  });

  factory PolarSleepData.fromJson(Map<String, dynamic> json) =>
      _$PolarSleepDataFromJson(json);

  Map<String, dynamic> toJson() => _$PolarSleepDataToJson(this);
}

/// Contains the results of sleep analysis including total sleep duration,
/// continuous sleep duration, and detailed sleep intervals with sleep stages
@JsonSerializable()
class SleepAnalysisResult {
  /// Total duration of sleep
  @DurationConverter()
  final Duration sleepDuration;
  
  /// Duration of continuous sleep without interruptions
  @DurationConverter()
  final Duration continuousSleepDuration;
  
  /// List of sleep intervals with detailed stage information
  final List<SleepInterval> sleepIntervals;

  SleepAnalysisResult({
    required this.sleepDuration,
    required this.continuousSleepDuration,
    required this.sleepIntervals,
  });

  factory SleepAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$SleepAnalysisResultFromJson(json);

  Map<String, dynamic> toJson() => _$SleepAnalysisResultToJson(this);
}

/// Represents a single interval of sleep with start time, end time, and sleep stage
@JsonSerializable()
class SleepInterval {
  /// The time when this sleep interval started
  final DateTime startTime;
  
  /// The time when this sleep interval ended
  final DateTime endTime;
  
  /// The stage of sleep during this interval
  final PolarSleepStage sleepStage;

  SleepInterval({
    required this.startTime,
    required this.endTime,
    required this.sleepStage,
  });

  factory SleepInterval.fromJson(Map<String, dynamic> json) =>
      _$SleepIntervalFromJson(json);

  Map<String, dynamic> toJson() => _$SleepIntervalToJson(this);
}
