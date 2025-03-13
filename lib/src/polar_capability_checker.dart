import 'package:polar/polar.dart';

/// Utility class for checking Polar device capabilities and feature support
class PolarCapabilityChecker {
  /// Checks if a specific feature is supported by a Polar device
  /// 
  /// Parameters:
  ///   - [identifier]: Polar device id or address
  ///   - [feature]: The feature to check for support
  ///   - [polar]: Instance of the Polar API
  /// 
  /// Returns true if the feature is supported, false otherwise
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
