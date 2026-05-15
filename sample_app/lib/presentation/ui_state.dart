import 'log_entry.dart';

/// Single source of truth the screen renders. The ViewModel emits one of
/// these for every state change; the screen diffs the parts it cares about
/// without holding any state of its own.
class UiState {
  final Status status;
  final bool isConfigured;
  final bool isWorking;
  final List<LogEntry> logEntries;
  final String? transientMessage;

  const UiState({
    required this.status,
    required this.isConfigured,
    required this.isWorking,
    required this.logEntries,
    this.transientMessage,
  });

  static const initial = UiState(
    status: Status.notConfigured,
    isConfigured: false,
    isWorking: false,
    logEntries: [],
  );

  UiState copyWith({
    Status? status,
    bool? isConfigured,
    bool? isWorking,
    List<LogEntry>? logEntries,
    String? transientMessage,
    bool clearTransientMessage = false,
  }) {
    return UiState(
      status: status ?? this.status,
      isConfigured: isConfigured ?? this.isConfigured,
      isWorking: isWorking ?? this.isWorking,
      logEntries: logEntries ?? this.logEntries,
      transientMessage: clearTransientMessage
          ? null
          : (transientMessage ?? this.transientMessage),
    );
  }
}

enum Status { notConfigured, configured, testing }
