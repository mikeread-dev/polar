import 'package:flutter/foundation.dart';
import 'package:polar/polar.dart';

const identifier = '1C709B20';
final polar = Polar();

void example() {
  polar.connectToDevice(identifier);
  streamWhenReady();
}

/// Example: Set up automatic PPI recording on system start
void setupAutomaticPpiRecording() async {
  // Wait for device connection
  await polar.deviceConnected.firstWhere((device) => device.deviceId == identifier);
  
  // Create a trigger for PPI recording on system start
  final trigger = PolarOfflineRecordingTrigger.ppiOnSystemStart();
  
  try {
    // Set the offline recording trigger
    await polar.setOfflineRecordingTrigger(identifier, trigger);
    debugPrint('Offline recording trigger set successfully');
    
    // Restart the device for the trigger to take effect
    await polar.doRestart(identifier, preservePairingInformation: true);
    debugPrint('Device restart initiated');
  } catch (e) {
    debugPrint('Error setting up automatic PPI recording: $e');
  }
}

/// Example: Disable automatic recording
void disableAutomaticRecording() async {
  try {
    // Create a disabled trigger
    final trigger = PolarOfflineRecordingTrigger.disabled();
    
    // Set the trigger to disabled
    await polar.setOfflineRecordingTrigger(identifier, trigger);
    debugPrint('Automatic recording disabled');
    
    // Restart the device for the change to take effect
    await polar.doRestart(identifier, preservePairingInformation: true);
    debugPrint('Device restart initiated');
  } catch (e) {
    debugPrint('Error disabling automatic recording: $e');
  }
}

void streamWhenReady() async {
  await polar.sdkFeatureReady.firstWhere(
    (e) =>
        e.identifier == identifier &&
        e.feature == PolarSdkFeature.onlineStreaming,
  );
  final availabletypes =
      await polar.getAvailableOnlineStreamDataTypes(identifier);

  debugPrint('available types: $availabletypes');

  if (availabletypes.contains(PolarDataType.hr)) {
    polar
        .startHrStreaming(identifier)
        .listen((e) => debugPrint('HR data received'));
  }
  if (availabletypes.contains(PolarDataType.ecg)) {
    polar
        .startEcgStreaming(identifier)
        .listen((e) => debugPrint('ECG data received'));
  }
  if (availabletypes.contains(PolarDataType.acc)) {
    polar
        .startAccStreaming(identifier)
        .listen((e) => debugPrint('ACC data received'));
  }
}
