/// Log levels for controlling TrustPin SDK output verbosity.
enum TrustPinLogLevel {
  /// No logging output.
  none('none'),

  /// Errors only. Recommended for production.
  error('error'),

  /// Errors and informational messages.
  info('info'),

  /// All messages, including debug. For development only.
  debug('debug');

  /// The string value representation of this log level.
  final String value;

  const TrustPinLogLevel(this.value);
}
