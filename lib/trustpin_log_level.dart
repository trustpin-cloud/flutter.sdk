/// Log levels for controlling TrustPin SDK output verbosity.
enum TrustPinLogLevel {
  /// No logging output.
  ///
  /// Completely disables all logging from the TrustPin SDK.
  /// Use this in production when you want minimal overhead.
  none('none'),

  /// Only error messages.
  ///
  /// Logs only critical errors that indicate certificate validation failures
  /// or configuration problems. Recommended for production environments.
  error('error'),

  /// Error and informational messages.
  ///
  /// Logs errors plus informational messages about certificate validation
  /// and configuration updates. Useful for staging environments.
  info('info'),

  /// All messages including debug information.
  ///
  /// Logs all messages including detailed debug information about certificate
  /// validation, network requests, and internal operations. Use this for
  /// development and troubleshooting.
  debug('debug');

  /// The string value representation of this log level.
  final String value;

  const TrustPinLogLevel(this.value);
}
