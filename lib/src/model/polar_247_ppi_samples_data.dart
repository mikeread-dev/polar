import 'package:json_annotation/json_annotation.dart';

part 'polar_247_ppi_samples_data.g.dart';

/// Represents 24/7 Peak-to-peak interval data samples from a Polar device.
@JsonSerializable()
class Polar247PPiSamplesData {
  /// The date of the sample.
  final DateTime date;

  /// The PPI samples for this date.
  final PolarPpiDataSampleData samples;

  /// Constructor
  Polar247PPiSamplesData({
    required this.date,
    required this.samples,
  });

  /// From json
  factory Polar247PPiSamplesData.fromJson(Map<String, dynamic> json) {
    return Polar247PPiSamplesData(
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      samples: PolarPpiDataSampleData.fromJson(json['samples'] as Map<String, dynamic>),
    );
  }

  /// To json
  Map<String, dynamic> toJson() => {
    'date': date.millisecondsSinceEpoch,
    'samples': samples.toJson(),
  };
}

/// Represents a sample of Pulse-to-Pulse Interval (PPi) data.
@JsonSerializable()
class PolarPpiDataSampleData {
  /// The start time of the sample session.
  final String startTime;

  /// The trigger type for the sample.
  final String triggerType;

  /// List of Peak-to-Peak interval values in the sample session.
  final List<int> ppiValueList;

  /// List of error estimate values in the sample session.
  final List<int> ppiErrorEstimateList;

  /// List of status values in the sample session.
  final List<PPiSampleStatusData> statusList;

  /// Constructor
  PolarPpiDataSampleData({
    required this.startTime,
    required this.triggerType,
    required this.ppiValueList,
    required this.ppiErrorEstimateList,
    required this.statusList,
  });

  /// From json
  factory PolarPpiDataSampleData.fromJson(Map<String, dynamic> json) {
    return PolarPpiDataSampleData(
      startTime: json['startTime'] as String,
      triggerType: json['triggerType'] as String,
      ppiValueList: (json['ppiValueList'] as List).cast<int>(),
      ppiErrorEstimateList: (json['ppiErrorEstimateList'] as List).cast<int>(),
      statusList: (json['statusList'] as List)
          .map((e) => PPiSampleStatusData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// To json
  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'triggerType': triggerType,
    'ppiValueList': ppiValueList,
    'ppiErrorEstimateList': ppiErrorEstimateList,
    'statusList': statusList.map((e) => e.toJson()).toList(),
  };
}

/// Represents the status of a PPi sample.
@JsonSerializable()
class PPiSampleStatusData {
  /// The skin contact status.
  final String skinContact;

  /// The movement status.
  final String movement;

  /// The interval status.
  final String intervalStatus;

  /// Constructor
  PPiSampleStatusData({
    required this.skinContact,
    required this.movement,
    required this.intervalStatus,
  });

  /// From json
  factory PPiSampleStatusData.fromJson(Map<String, dynamic> json) {
    return PPiSampleStatusData(
      skinContact: json['skinContact'] as String,
      movement: json['movement'] as String,
      intervalStatus: json['intervalStatus'] as String,
    );
  }

  /// To json
  Map<String, dynamic> toJson() => {
    'skinContact': skinContact,
    'movement': movement,
    'intervalStatus': intervalStatus,
  };
} 