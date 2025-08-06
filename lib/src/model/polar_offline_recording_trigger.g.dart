// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_cast, require_trailing_commas

part of 'polar_offline_recording_trigger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolarOfflineRecordingTrigger _$PolarOfflineRecordingTriggerFromJson(
        Map<String, dynamic> json) =>
    PolarOfflineRecordingTrigger(
      triggerMode: $enumDecode(
          _$PolarOfflineRecordingTriggerModeEnumMap, json['triggerMode']),
      triggerFeatures: _triggerFeaturesFromJson(
          json['triggerFeatures'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PolarOfflineRecordingTriggerToJson(
        PolarOfflineRecordingTrigger instance) =>
    <String, dynamic>{
      'triggerMode': instance.triggerMode.toJson(),
      'triggerFeatures': _triggerFeaturesToJson(instance.triggerFeatures),
    };

const _$PolarOfflineRecordingTriggerModeEnumMap = {
  PolarOfflineRecordingTriggerMode.triggerDisabled: 'triggerDisabled',
  PolarOfflineRecordingTriggerMode.triggerSystemStart: 'triggerSystemStart',
  PolarOfflineRecordingTriggerMode.triggerExerciseStart: 'triggerExerciseStart',
};
