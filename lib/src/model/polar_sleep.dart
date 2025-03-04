class PolarSleepData {
  final DateTime date;
  final SleepAnalysisResult analysis;

  PolarSleepData({
    required this.date,
    required this.analysis,
  });

  factory PolarSleepData.fromJson(Map<String, dynamic> json) {
    return PolarSleepData(
      date: DateTime.parse(json['date']),
      analysis: SleepAnalysisResult.fromJson(json['analysis']),
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
      sleepDuration: Duration(milliseconds: json['sleepDuration']),
      continuousSleepDuration: Duration(milliseconds: json['continuousSleepDuration']),
      sleepIntervals: (json['sleepIntervals'] as List)
          .map((e) => SleepInterval.fromJson(e))
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
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      sleepStage: json['sleepStage'],
    );
  }
}