class PolarConfig {
  final Duration connectionTimeout;
  final Duration streamingTimeout;
  final bool autoReconnect;
  final bool handlePermissions;
  final LogLevel logLevel;

  const PolarConfig({
    this.connectionTimeout = const Duration(seconds: 30),
    this.streamingTimeout = const Duration(seconds: 10),
    this.autoReconnect = true,
    this.handlePermissions = true,
    this.logLevel = LogLevel.info,
  });
}

enum LogLevel { debug, info, warning, error }