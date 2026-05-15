/// One line in the in-app log feed. The icon column mirrors what the
/// original sample printed inline so the visual look of the log is preserved.
class LogEntry {
  final String timestamp;
  final LogLevel level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

enum LogLevel {
  info('⚙️'),
  success('✅'),
  warning('⚠️'),
  error('❌'),
  debug('🐛');

  final String icon;

  const LogLevel(this.icon);
}
