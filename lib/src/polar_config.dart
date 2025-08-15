/// Configuration class for Polar SDK settings
class PolarConfig {
  /// Timeout duration for device connections
  final Duration connectionTimeout;

  /// Timeout duration for streaming operations
  final Duration streamingTimeout;

  /// Whether to automatically attempt to reconnect if connection is lost
  final bool autoReconnect;

  /// Whether to handle Bluetooth permissions automatically
  final bool handlePermissions;

  /// Level of logging to output
  final LogLevel logLevel;

  /// Creates a new [PolarConfig] with the given parameters
  const PolarConfig({
    this.connectionTimeout = const Duration(seconds: 30),
    this.streamingTimeout = const Duration(seconds: 10),
    this.autoReconnect = true,
    this.handlePermissions = true,
    this.logLevel = LogLevel.info,
  });
}

/// Available logging levels for the Polar SDK
enum LogLevel { 
  /// Debug level logging - most verbose
  debug, 
  /// Info level logging - general information
  info, 
  /// Warning level logging - potential issues
  warning, 
  /// Error level logging - errors only
  error 
}