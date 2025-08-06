import 'package:json_annotation/json_annotation.dart';
import 'package:polar/src/model/polar_device_data_type.dart';
import 'package:polar/src/model/polar_offline_recording_trigger_mode.dart';
import 'package:polar/src/model/polar_sensor_setting.dart';

part 'polar_offline_recording_trigger.g.dart';

/// Polar offline recording trigger configuration
@JsonSerializable(explicitToJson: true)
class PolarOfflineRecordingTrigger {
  /// The mode of the trigger
  final PolarOfflineRecordingTriggerMode triggerMode;

  /// Dictionary containing the PolarDataType keys for enabled triggers. 
  /// Dictionary is empty if triggerMode is PolarOfflineRecordingTriggerMode.triggerDisabled. 
  /// In case of the PolarDataType.ppi or PolarDataType.hr the settings is null
  @JsonKey(
    toJson: _triggerFeaturesToJson,
    fromJson: _triggerFeaturesFromJson,
  )
  final Map<PolarDataType, PolarSensorSetting?> triggerFeatures;

  /// Constructor
  PolarOfflineRecordingTrigger({
    required this.triggerMode,
    required this.triggerFeatures,
  });

  /// Create a trigger for PPI recording on system start
  factory PolarOfflineRecordingTrigger.ppiOnSystemStart() {
    return PolarOfflineRecordingTrigger(
      triggerMode: PolarOfflineRecordingTriggerMode.triggerSystemStart,
      triggerFeatures: {
        PolarDataType.ppi: null, // PPI doesn't require settings
      },
    );
  }

  /// Create a disabled trigger
  factory PolarOfflineRecordingTrigger.disabled() {
    return PolarOfflineRecordingTrigger(
      triggerMode: PolarOfflineRecordingTriggerMode.triggerDisabled,
      triggerFeatures: {},
    );
  }

  /// From json
  factory PolarOfflineRecordingTrigger.fromJson(Map<String, dynamic> json) =>
      _$PolarOfflineRecordingTriggerFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$PolarOfflineRecordingTriggerToJson(this);

  @override
  String toString() {
    return 'PolarOfflineRecordingTrigger(triggerMode: $triggerMode, triggerFeatures: $triggerFeatures)';
  }
}

/// Helper function to convert triggerFeatures map to JSON
Map<String, dynamic> _triggerFeaturesToJson(Map<PolarDataType, PolarSensorSetting?> triggerFeatures) {
  return triggerFeatures.map((key, value) => MapEntry(
    key.name, // Convert enum to string
    value?.toJson(), // Convert PolarSensorSetting to JSON or null
  ));
}

/// Helper function to convert JSON to triggerFeatures map
Map<PolarDataType, PolarSensorSetting?> _triggerFeaturesFromJson(Map<String, dynamic> json) {
  return json.map((key, value) {
    final dataType = PolarDataType.values.firstWhere((e) => e.name == key);
    final setting = value != null ? PolarSensorSetting.fromJson(value as Map<String, dynamic>) : null;
    return MapEntry(dataType, setting);
  });
}