import '../domain/repository/logger.dart';
import 'log_entry.dart';

/// [Logger] implementation that pushes formatted entries into a callback for
/// the ViewModel to fold into [UiState.logEntries].
///
/// The sink stays in the presentation layer because the timestamp format and
/// the UI-bound side effect are presentation concerns; use cases only see the
/// abstract [Logger] interface.
class UiLogSink implements Logger {
  final void Function(LogEntry entry) onEntry;

  const UiLogSink(this.onEntry);

  @override
  void info(String message) => _emit(LogLevel.info, message);

  @override
  void success(String message) => _emit(LogLevel.success, message);

  @override
  void warning(String message) => _emit(LogLevel.warning, message);

  @override
  void error(String message) => _emit(LogLevel.error, message);

  @override
  void debug(String message) => _emit(LogLevel.debug, message);

  void _emit(LogLevel level, String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    onEntry(LogEntry(timestamp: '$hh:$mm:$ss', level: level, message: message));
  }
}
