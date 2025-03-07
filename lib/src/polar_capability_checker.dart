import 'package:polar/polar.dart';

class PolarCapabilityChecker {
  static Future<bool> isFeatureSupported(
    String identifier,
    PolarSdkFeature feature,
    Polar polar,
  ) async {
    try {
      // Wait for device to be ready
      await polar.sdkFeatureReady.firstWhere(
        (e) => e.identifier == identifier && e.feature == feature,
      ).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gets the set of supported streaming features for a given device
  /// 
  /// Parameters:
  ///   - [identifier]: Polar device id or address
  ///   - [polar]: Instance of the Polar API
  /// 
  /// Returns an empty set if the features cannot be retrieved
  static Future<Set<PolarDataType>> getSupportedStreamingFeatures(
    String identifier,
    Polar polar,
  ) async {
    try {
      return await polar.getAvailableOnlineStreamDataTypes(identifier);
    } catch (_) {
      return {};
    }
  }
}
