class PolarSleepData {
  final DateTime date;
  final SleepAnalysisResult analysis;

  PolarSleepData({
    required this.date,
    required this.analysis,
  });

  factory PolarSleepData.fromJson(Map<dynamic, dynamic> json) {
    return PolarSleepData(
      date: DateTime.parse(json['date'] as String),
      analysis: SleepAnalysisResult.fromJson(
        Map<String, dynamic>.from(json['analysis'] as Map),
      ),
    );
  }
}

class SleepAnalysisResult {
  final Duration sleepDuration;
  final Duration continuousSleepDuration;
  final List<SleepInterval> sleepIntervals;

  SleepAnalysisResult({
    required this.sleepDuration,
    required this.continuousSleepDuration,
    required this.sleepIntervals,
  });

  factory SleepAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SleepAnalysisResult(
      sleepDuration: Duration(milliseconds: json['sleepDuration'] as int),
      continuousSleepDuration: Duration(milliseconds: json['continuousSleepDuration'] as int),
      sleepIntervals: (json['sleepIntervals'] as List)
          .map((e) => SleepInterval.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class SleepInterval {
  final DateTime startTime;
  final DateTime endTime;
  final String sleepStage;

  SleepInterval({
    required this.startTime,
    required this.endTime,
    required this.sleepStage,
  });

  factory SleepInterval.fromJson(Map<String, dynamic> json) {
    return SleepInterval(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      sleepStage: json['sleepStage'] as String,
    );
  }
}
