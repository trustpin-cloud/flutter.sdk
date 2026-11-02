import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trustpin_attest/trustpin_attest.dart';

import '../domain/model/attestation_status.dart';
import '../domain/model/domain_error.dart';
import '../domain/repository/attestation_repository.dart';
import '../domain/repository/logger.dart';
import '../domain/usecase/attestation_use_cases.dart';
import 'log_entry.dart';
import 'ui_log_sink.dart';

typedef SetUpAttestationFactory =
    SetUpAttestationUseCase Function(Logger logger);
typedef CallProtectedEndpointFactory =
    CallProtectedEndpointUseCase Function(Logger logger);
typedef CallSensitiveEndpointFactory =
    CallSensitiveEndpointUseCase Function(Logger logger);
typedef SignOutSessionFactory = SignOutSessionUseCase Function(Logger logger);
typedef ResetAttestationFactory =
    ResetAttestationUseCase Function(Logger logger);

/// What the Attestation tab renders.
class AttestationUiState {
  final AttestationStatus status;
  final bool isConfigured;
  final bool isBusy;
  final ProtectedCallOutcome? lastOutcome;
  final List<LogEntry> logEntries;

  const AttestationUiState({
    required this.status,
    required this.isConfigured,
    required this.isBusy,
    required this.lastOutcome,
    required this.logEntries,
  });

  static const initial = AttestationUiState(
    status: AttestationStatus.notConfigured,
    isConfigured: false,
    isBusy: false,
    lastOutcome: null,
    logEntries: [],
  );

  AttestationUiState copyWith({
    AttestationStatus? status,
    bool? isConfigured,
    bool? isBusy,
    ProtectedCallOutcome? lastOutcome,
    List<LogEntry>? logEntries,
  }) => AttestationUiState(
    status: status ?? this.status,
    isConfigured: isConfigured ?? this.isConfigured,
    isBusy: isBusy ?? this.isBusy,
    lastOutcome: lastOutcome ?? this.lastOutcome,
    logEntries: logEntries ?? this.logEntries,
  );
}

/// Orchestrates the Attestation tab: setup, the protected call, sign-out and
/// reset, with the SDK's state and log output in the tab's own log.
class AttestationViewModel extends ChangeNotifier {
  final AttestationRepository _repository;
  final SetUpAttestationFactory _setUp;
  final CallProtectedEndpointFactory _callProtectedEndpoint;
  final CallSensitiveEndpointFactory _callSensitiveEndpoint;
  final SignOutSessionFactory _signOut;
  final ResetAttestationFactory _reset;

  AttestationUiState _state = AttestationUiState.initial;

  AttestationUiState get state => _state;

  late final UiLogSink _logSink = UiLogSink((entry) {
    _update((s) => s.copyWith(logEntries: [...s.logEntries, entry]));
  });

  /// The attestation module's own log output, routed into this tab's log.
  late final StreamSubscription<TrustPinAttestLogEvent> _sdkLogs;

  /// The SDK's structured events, one line each in this tab's log.
  late final StreamSubscription<TrustPinAttestEvent> _sdkEvents;
  StreamSubscription<TrustPinAttestState>? _states;

  AttestationViewModel({
    required AttestationRepository repository,
    required SetUpAttestationFactory setUp,
    required CallProtectedEndpointFactory callProtectedEndpoint,
    required CallSensitiveEndpointFactory callSensitiveEndpoint,
    required SignOutSessionFactory signOut,
    required ResetAttestationFactory reset,
  }) : _repository = repository,
       _setUp = setUp,
       _callProtectedEndpoint = callProtectedEndpoint,
       _callSensitiveEndpoint = callSensitiveEndpoint,
       _signOut = signOut,
       _reset = reset {
    _sdkLogs = TrustPinAttest.logs.listen(
      _onSdkLog,
      onError: (Object e) => _logSink.error('SDK log stream: $e'),
    );
    _sdkEvents = _repository.events.listen(
      (event) => _logSink.info('[Event] $event'),
      onError: (Object e) => _logSink.error('SDK event stream: $e'),
    );
    _logSink.info('Attestation pairs with the default TrustPin instance');
    _logSink.info('Configure pinning first, then set up attestation');
  }

  Future<void> setUp() async {
    _update((s) => s.copyWith(isBusy: true));
    try {
      await _setUp(_logSink).call();
      _update((s) => s.copyWith(isConfigured: true));
      _states ??= _repository.states.listen(_onState);
    } on DomainError {
      // Logged by the use case; setup can be retried.
    } finally {
      _update((s) => s.copyWith(isBusy: false));
    }
  }

  Future<void> callProtectedEndpoint() async {
    _update((s) => s.copyWith(isBusy: true));
    try {
      final outcome = await _callProtectedEndpoint(_logSink).call();
      _update((s) => s.copyWith(lastOutcome: outcome));
    } on DomainError {
      // Logged by the use case.
    } finally {
      _update((s) => s.copyWith(isBusy: false));
    }
  }

  Future<void> callSensitiveEndpoint() async {
    _update((s) => s.copyWith(isBusy: true));
    try {
      final outcome = await _callSensitiveEndpoint(_logSink).call();
      _update((s) => s.copyWith(lastOutcome: outcome));
    } on DomainError {
      // Logged by the use case.
    } finally {
      _update((s) => s.copyWith(isBusy: false));
    }
  }

  void signOut() => _signOut(_logSink).call();

  Future<void> reset() async {
    _update((s) => s.copyWith(isBusy: true));
    try {
      await _reset(_logSink).call();
    } on DomainError {
      // Logged by the use case.
    } finally {
      _update((s) => s.copyWith(isBusy: false));
    }
  }

  void clearLog() {
    _update((s) => s.copyWith(logEntries: const <LogEntry>[]));
    _logSink.info('🧹 Log cleared');
  }

  void _onState(TrustPinAttestState state) {
    final status = AttestationStatus(state);
    _update((s) => s.copyWith(status: status));
    _logSink.info('🛡 Attestation state: ${status.label}');
  }

  void _onSdkLog(TrustPinAttestLogEvent event) {
    final message = '[TrustPinAttest] ${event.message}';
    switch (event.level) {
      case TrustPinAttestLogLevel.error:
        _logSink.error(message);
      case TrustPinAttestLogLevel.warning:
        _logSink.warning(message);
      case TrustPinAttestLogLevel.debug:
        _logSink.debug(message);
      case TrustPinAttestLogLevel.info || TrustPinAttestLogLevel.none:
        _logSink.info(message);
    }
  }

  @override
  void dispose() {
    _sdkLogs.cancel();
    _sdkEvents.cancel();
    _states?.cancel();
    super.dispose();
  }

  void _update(AttestationUiState Function(AttestationUiState) reducer) {
    _state = reducer(_state);
    notifyListeners();
  }
}
