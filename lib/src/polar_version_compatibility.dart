/// Handles compatibility between different SDK versions
class PolarVersionCompatibility {
  /// Current version of the Polar SDK
  static const currentSdkVersion = '6.2.0';
  
  /// Checks if the current SDK version supports the new streaming API
  /// 
  /// Returns true if the SDK version is 5.0.0 or higher
  static bool shouldUseNewStreamingApi() {
    // Example of version-specific logic
    return compareVersions(currentSdkVersion, '5.0.0') >= 0;
  }

  /// Checks if the current SDK version supports temperature sensor features
  /// 
  /// Returns true if the SDK version is 5.7.0 or higher
  static bool supportsTemperatureSensor() {
    return compareVersions(currentSdkVersion, '5.7.0') >= 0;
  }

  /// Compares two version strings in semantic versioning format
  /// 
  /// Parameters:
  ///   - [v1]: First version string
  ///   - [v2]: Second version string
  /// 
  /// Returns:
  ///   - 1 if v1 is greater than v2
  ///   - -1 if v1 is less than v2
  ///   - 0 if v1 equals v2
  static int compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }
}