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
      sleepDuration:
          Duration(microseconds: (json['sleepDuration'] as num).toInt()),
      continuousSleepDuration: Duration(
          microseconds: (json['continuousSleepDuration'] as num).toInt()),
      sleepIntervals: (json['sleepIntervals'] as List<dynamic>)
          .map((e) => SleepInterval.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SleepAnalysisResultToJson(
        SleepAnalysisResult instance) =>
    <String, dynamic>{
      'sleepDuration': instance.sleepDuration.inMicroseconds,
      'continuousSleepDuration':
          instance.continuousSleepDuration.inMicroseconds,
      'sleepIntervals': instance.sleepIntervals,
    };

SleepInterval _$SleepIntervalFromJson(Map<String, dynamic> json) =>
    SleepInterval(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      sleepStage: json['sleepStage'] as PolarSleepStage,
    );

Map<String, dynamic> _$SleepIntervalToJson(SleepInterval instance) =>
    <String, dynamic>{
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'sleepStage': instance.sleepStage,
    };
