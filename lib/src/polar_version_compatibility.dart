/// Handles compatibility between different SDK versions
class PolarVersionCompatibility {
  static const currentSdkVersion = '5.14.0';
  
  static bool shouldUseNewStreamingApi() {
    // Example of version-specific logic
    return _compareVersions(currentSdkVersion, '5.0.0') >= 0;
  }

  static bool supportsTemperatureSensor() {
    return _compareVersions(currentSdkVersion, '5.7.0') >= 0;
  }

  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }
}