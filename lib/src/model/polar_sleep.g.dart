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
