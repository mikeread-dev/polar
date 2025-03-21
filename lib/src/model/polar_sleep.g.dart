// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_cast, require_trailing_commas

part of 'polar_sleep.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolarSleepData _$PolarSleepDataFromJson(Map<String, dynamic> json) =>
    PolarSleepData(
      date:
          json['date'] == null ? null : DateTime.parse(json['date'] as String),
      analysis: json['result'] == null
          ? null
          : SleepAnalysisResult.fromJson(
              json['result'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PolarSleepDataToJson(PolarSleepData instance) =>
    <String, dynamic>{
      'date': instance.date?.toIso8601String(),
      'result': instance.analysis,
    };

// ignore: unused_element
SleepAnalysisResult _$SleepAnalysisResultFromJson(Map<String, dynamic> json) =>
    SleepAnalysisResult(
      batteryRanOut: json['batteryRanOut'] as bool?,
      deviceId: json['deviceId'] as String?,
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
      sleepCycles: (json['sleepCycles'] as List<dynamic>?)
          ?.map((e) => SleepCycle.fromJson(e as Map<String, dynamic>))
          .toList(),
      sleepEndOffsetSeconds: (json['sleepEndOffsetSeconds'] as num?)?.toInt(),
      sleepEndTime: json['sleepEndTime'] == null
          ? null
          : DateTime.parse(json['sleepEndTime'] as String),
      sleepGoalMinutes: (json['sleepGoalMinutes'] as num?)?.toInt(),
      sleepResultDate: json['sleepResultDate'] == null
          ? null
          : DateTime.parse(json['sleepResultDate'] as String),
      sleepStartOffsetSeconds:
          (json['sleepStartOffsetSeconds'] as num?)?.toInt(),
      sleepStartTime: json['sleepStartTime'] == null
          ? null
          : DateTime.parse(json['sleepStartTime'] as String),
      sleepWakePhases: (json['sleepWakePhases'] as List<dynamic>?)
          ?.map((e) => SleepWakePhase.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

// ignore: unused_element
Map<String, dynamic> _$SleepAnalysisResultToJson(
        SleepAnalysisResult instance) =>
    <String, dynamic>{
      'batteryRanOut': instance.batteryRanOut,
      'deviceId': instance.deviceId,
      'lastModified': instance.lastModified?.toIso8601String(),
      'sleepCycles': instance.sleepCycles,
      'sleepEndOffsetSeconds': instance.sleepEndOffsetSeconds,
      'sleepEndTime': instance.sleepEndTime?.toIso8601String(),
      'sleepGoalMinutes': instance.sleepGoalMinutes,
      'sleepResultDate': instance.sleepResultDate?.toIso8601String(),
      'sleepStartOffsetSeconds': instance.sleepStartOffsetSeconds,
      'sleepStartTime': instance.sleepStartTime?.toIso8601String(),
      'sleepWakePhases': instance.sleepWakePhases,
    };

SleepCycle _$SleepCycleFromJson(Map<String, dynamic> json) => SleepCycle(
      secondsFromSleepStart: (json['secondsFromSleepStart'] as num).toInt(),
      sleepDepthStart: (json['sleepDepthStart'] as num).toDouble(),
    );

Map<String, dynamic> _$SleepCycleToJson(SleepCycle instance) =>
    <String, dynamic>{
      'secondsFromSleepStart': instance.secondsFromSleepStart,
      'sleepDepthStart': instance.sleepDepthStart,
    };

SleepWakePhase _$SleepWakePhaseFromJson(Map<String, dynamic> json) =>
    SleepWakePhase(
      secondsFromSleepStart: (json['secondsFromSleepStart'] as num).toInt(),
      state: json['state'] as String,
    );

Map<String, dynamic> _$SleepWakePhaseToJson(SleepWakePhase instance) =>
    <String, dynamic>{
      'secondsFromSleepStart': instance.secondsFromSleepStart,
      'state': instance.state,
    };
