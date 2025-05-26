// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_cast, require_trailing_commas

part of 'polar_247_ppi_samples_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Polar247PPiSamplesData _$Polar247PPiSamplesDataFromJson(
        Map<String, dynamic> json) =>
    Polar247PPiSamplesData(
      date: DateTime.parse(json['date'] as String),
      samples: PolarPpiDataSampleData.fromJson(
          json['samples'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$Polar247PPiSamplesDataToJson(
        Polar247PPiSamplesData instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'samples': instance.samples,
    };

PolarPpiDataSampleData _$PolarPpiDataSampleDataFromJson(
        Map<String, dynamic> json) =>
    PolarPpiDataSampleData(
      startTime: json['startTime'] as String,
      triggerType: json['triggerType'] as String,
      ppiValueList: (json['ppiValueList'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      ppiErrorEstimateList: (json['ppiErrorEstimateList'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      statusList: (json['statusList'] as List<dynamic>)
          .map((e) => PPiSampleStatusData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PolarPpiDataSampleDataToJson(
        PolarPpiDataSampleData instance) =>
    <String, dynamic>{
      'startTime': instance.startTime,
      'triggerType': instance.triggerType,
      'ppiValueList': instance.ppiValueList,
      'ppiErrorEstimateList': instance.ppiErrorEstimateList,
      'statusList': instance.statusList,
    };

PPiSampleStatusData _$PPiSampleStatusDataFromJson(Map<String, dynamic> json) =>
    PPiSampleStatusData(
      skinContact: json['skinContact'] as String,
      movement: json['movement'] as String,
      intervalStatus: json['intervalStatus'] as String,
    );

Map<String, dynamic> _$PPiSampleStatusDataToJson(
        PPiSampleStatusData instance) =>
    <String, dynamic>{
      'skinContact': instance.skinContact,
      'movement': instance.movement,
      'intervalStatus': instance.intervalStatus,
    };
