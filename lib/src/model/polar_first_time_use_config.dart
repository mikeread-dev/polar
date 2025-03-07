/// Enum representing the training background levels
enum TrainingBackground {
  /// Occasional training (value: 10)
  occasional(10),
  /// Regular training (value: 20)
  regular(20),
  /// Frequent training (value: 30)
  frequent(30),
  /// Heavy training (value: 40)
  heavy(40),
  /// Semi-professional training (value: 50)
  semiPro(50),
  /// Professional training (value: 60)
  pro(60);

  /// The numeric value associated with the training background level
  final int value;
  
  /// Creates a [TrainingBackground] with the specified [value]
  const TrainingBackground(this.value);
}

/// Enum representing the typical day activity levels
enum TypicalDay {
  /// Mostly moving throughout the day (value: 1)
  mostlyMoving(1),
  /// Mostly sitting throughout the day (value: 2)
  mostlySitting(2),
  /// Mostly standing throughout the day (value: 3)
  mostlyStanding(3);

  /// The numeric value associated with the typical day activity level
  final int value;
  
  /// Creates a [TypicalDay] with the specified [value]
  const TypicalDay(this.value);
}

/// Configuration class for First Time Use setup of Polar devices.
///
/// This class encapsulates all the necessary parameters required for initializing
/// a Polar device for first-time use. It includes user physical characteristics,
/// fitness metrics, and preferences.
///
/// All parameters are validated upon object creation to ensure they fall within
/// acceptable ranges as defined by the Polar SDK.
///
/// Example usage:
/// ```dart
/// final config = PolarFirstTimeUseConfig(
///   gender: 'Male',
///   birthDate: DateTime(1990, 1, 1),
///   height: 180,
///   weight: 75,
///   maxHeartRate: 180,
///   vo2Max: 50,
///   restingHeartRate: 60,
///   trainingBackground: TrainingBackground.occasional,
///   deviceTime: '2025-01-24T12:00:00Z',
///   typicalDay: TypicalDay.mostlySitting,
///   sleepGoalMinutes: 480,
/// );
/// ```
///
/// Throws [ArgumentError] if any of the parameters are outside their valid ranges:
/// - height must be between 90 and 240 cm
/// - weight must be between 15 and 300 kg
/// - maxHeartRate must be between 100 and 240 bpm
/// - restingHeartRate must be between 20 and 120 bpm
/// - vo2Max must be between 10 and 95
/// - gender must be either "Male" or "Female"
class PolarFirstTimeUseConfig {
  /// User's gender. Must be either "Male" or "Female"
  final String gender;
  
  /// User's date of birth
  final DateTime birthDate;
  
  /// User's height in centimeters (90-240 cm)
  final int height;
  
  /// User's weight in kilograms (15-300 kg)
  final int weight;
  
  /// User's maximum heart rate in beats per minute (100-240 bpm)
  final int maxHeartRate;
  
  /// User's VO2 max value (10-95)
  final int vo2Max;
  
  /// User's resting heart rate in beats per minute (20-120 bpm)
  final int restingHeartRate;
  
  /// User's training background level
  final TrainingBackground trainingBackground;
  
  /// Device time in ISO 8601 format
  final String deviceTime;
  
  /// User's typical daily activity level
  final TypicalDay typicalDay;
  
  /// User's sleep goal in minutes
  final int sleepGoalMinutes;

  /// Creates a new [PolarFirstTimeUseConfig] instance with the specified parameters.
  ///
  /// All parameters are required and will be validated against their acceptable ranges.
  /// Throws [ArgumentError] if any parameter is invalid.
  PolarFirstTimeUseConfig({
    required this.gender,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.maxHeartRate,
    required this.vo2Max,
    required this.restingHeartRate,
    required this.trainingBackground,
    required this.deviceTime,
    required this.typicalDay,
    required this.sleepGoalMinutes,
  }) {
    // Validate ranges
    if (height < 90 || height > 240) {
      throw ArgumentError('Height must be between 90 and 240 cm');
    }
    if (weight < 15 || weight > 300) {
      throw ArgumentError('Weight must be between 15 and 300 kg');
    }
    if (maxHeartRate < 100 || maxHeartRate > 240) {
      throw ArgumentError('Max heart rate must be between 100 and 240 bpm');
    }
    if (restingHeartRate < 20 || restingHeartRate > 120) {
      throw ArgumentError('Resting heart rate must be between 20 and 120 bpm');
    }
    if (vo2Max < 10 || vo2Max > 95) {
      throw ArgumentError('VO2 max must be between 10 and 95');
    }
    if (!['Male', 'Female'].contains(gender)) {
      throw ArgumentError('Gender must be either "Male" or "Female"');
    }
  }

  /// Converts the configuration into a map format suitable for sending to the Polar device.
  ///
  /// Returns a [Map] containing all configuration parameters in the format expected by
  /// the Polar SDK. Date values are converted to ISO 8601 format (date only), and enum
  /// values are converted to their corresponding integer values.
  Map<String, dynamic> toMap() {
    return {
      'gender': gender,
      'birthDate': birthDate.toIso8601String().split('T')[0],
      'height': height,
      'weight': weight,
      'maxHeartRate': maxHeartRate,
      'vo2Max': vo2Max,
      'restingHeartRate': restingHeartRate,
      'trainingBackground': trainingBackground.value,
      'deviceTime': deviceTime,
      'typicalDay': typicalDay.value,
      'sleepGoalMinutes': sleepGoalMinutes,
    };
  }
}

// final config = PolarFirstTimeUseConfig(
//   gender: 'Male',
//   birthDate: DateTime(1990, 1, 1),
//   height: 180,
//   weight: 75,
//   maxHeartRate: 180,
//   vo2Max: 50,
//   restingHeartRate: 60,
//   trainingBackground: TrainingBackground.occasional,
//   deviceTime: '2025-01-24T12:00:00Z',
//   typicalDay: TypicalDay.normal,
//   sleepGoalMinutes: 480,
// );

// await doFirstTimeUse('deviceId', config);
