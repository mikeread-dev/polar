// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_cast, require_trailing_commas

part of 'polar_sleep.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolarSleepData _$PolarSleepDataFromJson(Map<String, dynamic> json) =>
    PolarSleepData(
      date: DateTime.parse(json['date'] as String),
      analysis: SleepAnalysisResult.fromJson(
          json['analysis'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PolarSleepDataToJson(PolarSleepData instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'analysis': instance.analysis,
    };

SleepAnalysisResult _$SleepAnalysisResultFromJson(Map<String, dynamic> json) =>
    SleepAnalysisResult(
      sleepDuration: const DurationConverter()
          .fromJson((json['sleepDuration'] as num).toInt()),
      continuousSleepDuration: const DurationConverter()
          .fromJson((json['continuousSleepDuration'] as num).toInt()),
      sleepIntervals: (json['sleepIntervals'] as List<dynamic>)
          .map((e) => SleepInterval.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SleepAnalysisResultToJson(
        SleepAnalysisResult instance) =>
    <String, dynamic>{
      'sleepDuration': const DurationConverter().toJson(instance.sleepDuration),
      'continuousSleepDuration':
          const DurationConverter().toJson(instance.continuousSleepDuration),
      'sleepIntervals': instance.sleepIntervals,
    };

SleepInterval _$SleepIntervalFromJson(Map<String, dynamic> json) =>
    SleepInterval(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      sleepStage: SleepInterval._sleepStageFromJson(json['sleepStage']),
    );

Map<String, dynamic> _$SleepIntervalToJson(SleepInterval instance) =>
    <String, dynamic>{
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'sleepStage': _$PolarSleepStageEnumMap[instance.sleepStage]!,
    };

const _$PolarSleepStageEnumMap = {
  PolarSleepStage.awake: 'awake',
  PolarSleepStage.light: 'light',
  PolarSleepStage.deep: 'deep',
  PolarSleepStage.rem: 'rem',
};
