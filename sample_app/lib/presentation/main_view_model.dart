import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

import '../domain/model/domain_error.dart';
import '../domain/model/pinning_credentials.dart';
import '../domain/repository/configuration_repository.dart';
import '../domain/repository/logger.dart';
import '../domain/usecase/configure_pinning_from_bundle_use_case.dart';
import '../domain/usecase/configure_pinning_use_case.dart';
import '../domain/usecase/test_pinned_connection_use_case.dart';
import 'log_entry.dart';
import 'ui_action.dart';
import 'ui_log_sink.dart';
import 'ui_state.dart';

/// Use-case factory shape — each call returns a fresh use case bound to the
/// supplied [Logger]. Mirrors the Kotlin `(logger) -> UseCase` shape so a
/// request-scoped sink can be injected per action.
typedef ConfigureFactory = ConfigurePinningUseCase Function(Logger logger);
typedef ConfigureFromBundleFactory =
    ConfigurePinningFromBundleUseCase Function(Logger logger);
typedef TestConnectionFactory =
    TestPinnedConnectionUseCase Function(Logger logger);

/// Orchestrates use cases for the single-screen sample. Holds the canonical
/// [UiState] and exposes a single [dispatch] entry point — the widget tree
/// has no direct handle on the repositories or use cases.
class MainViewModel extends ChangeNotifier {
  final ConfigurationRepository _configurationRepository;
  final ConfigureFactory _configure;
  final ConfigureFromBundleFactory _configureFromBundle;
  final TestConnectionFactory _testConnection;

  UiState _state = UiState.initial;

  UiState get state => _state;

  late final UiLogSink _logSink = UiLogSink((entry) {
    _update((s) => s.copyWith(logEntries: [...s.logEntries, entry]));
  });

  /// Pin-validation verdicts from the native SDK (`TrustPin.validationEvents`).
  /// Fires for definitive verdicts only; the connection has already been
  /// allowed or rejected by the time an event arrives.
  late final StreamSubscription<TrustPinValidationEvent> _validationEvents;

  /// The native SDK's own log output (`TrustPin.logs`), routed into the same
  /// in-app feed as the sample's narrative so SDK-internal chatter is visible
  /// next to it.
  late final StreamSubscription<TrustPinLogEvent> _sdkLogs;

  MainViewModel({
    required ConfigurationRepository configurationRepository,
    required ConfigureFactory configure,
    required ConfigureFromBundleFactory configureFromBundle,
    required TestConnectionFactory testConnection,
  }) : _configurationRepository = configurationRepository,
       _configure = configure,
       _configureFromBundle = configureFromBundle,
       _testConnection = testConnection {
    _validationEvents = TrustPin.validationEvents.listen(
      _onValidationEvent,
      onError: (Object e) => _logSink.error('Validation event stream: $e'),
    );
    _sdkLogs = TrustPin.logs.listen(
      _onSdkLog,
      onError: (Object e) => _logSink.error('SDK log stream: $e'),
    );
    _logSink.info('TrustPin Flutter Sample started');
    _logSink.info('TrustPin configured for info-level logging');
    _state = _state.copyWith(
      isConfigured: _configurationRepository.isConfigured(),
    );
  }

  /// Telemetry hook: a real app would record failures with its analytics or
  /// crash-reporting pipeline; the sample folds them into the log feed.
  void _onValidationEvent(TrustPinValidationEvent event) {
    if (event.isSuccess) {
      _logSink.success('Pin validation succeeded for ${event.domain}');
    } else {
      _logSink.warning(
        'Pin validation FAILED for ${event.domain}: ${event.error!.code}',
      );
    }
  }

  void _onSdkLog(TrustPinLogEvent event) {
    final message = '[SDK] ${event.message}';
    switch (event.level) {
      case TrustPinLogLevel.error:
        _logSink.error(message);
      case TrustPinLogLevel.debug:
        _logSink.debug(message);
      case TrustPinLogLevel.info || TrustPinLogLevel.none:
        _logSink.info(message);
    }
  }

  @override
  void dispose() {
    _validationEvents.cancel();
    _sdkLogs.cancel();
    super.dispose();
  }

  Future<void> dispatch(UiAction action) async {
    switch (action) {
      case ConfigureAction():
        await _handleConfigure(action);
      case ConfigureFromBundleAction():
        await _handleConfigureFromBundle();
      case TestConnectionAction():
        await _handleTestConnection(action.url);
      case ClearLogAction():
        _update((s) => s.copyWith(logEntries: const <LogEntry>[]));
      case ConsumeTransientMessageAction():
        _update((s) => s.copyWith(clearTransientMessage: true));
    }
  }

  Future<void> _handleConfigure(ConfigureAction action) async {
    _update((s) => s.copyWith(isWorking: true));
    try {
      await _configure(_logSink).call(
        PinningCredentials(
          organizationId: action.organizationId,
          projectId: action.projectId,
          publicKey: action.publicKey,
          mode: TrustPinMode.strict,
        ),
      );
      _update(
        (s) => s.copyWith(
          isConfigured: true,
          isWorking: false,
          status: Status.configured,
          transientMessage: 'TrustPin configured successfully!',
        ),
      );
    } on DomainError catch (e) {
      _update(
        (s) => s.copyWith(
          isConfigured: _configurationRepository.isConfigured(),
          isWorking: false,
          transientMessage: 'Configuration failed: ${e.message}',
        ),
      );
    }
  }

  Future<void> _handleConfigureFromBundle() async {
    _update((s) => s.copyWith(isWorking: true));
    try {
      await _configureFromBundle(_logSink).call();
      _update(
        (s) => s.copyWith(
          isConfigured: true,
          isWorking: false,
          status: Status.configured,
          transientMessage: 'TrustPin configured from native bundle',
        ),
      );
    } on DomainError catch (e) {
      _update(
        (s) => s.copyWith(
          isConfigured: _configurationRepository.isConfigured(),
          isWorking: false,
          transientMessage: 'Configuration failed: ${e.message}',
        ),
      );
    }
  }

  Future<void> _handleTestConnection(String url) async {
    _update((s) => s.copyWith(isWorking: true, status: Status.testing));
    try {
      await _testConnection(_logSink).call(url);
      _update(
        (s) => s.copyWith(
          isWorking: false,
          status: Status.configured,
          transientMessage: 'Connection test successful!',
        ),
      );
    } on DomainError catch (e) {
      _update(
        (s) => s.copyWith(
          isWorking: false,
          status: s.isConfigured ? Status.configured : Status.notConfigured,
          transientMessage: _messageFor(e),
        ),
      );
    }
  }

  String _messageFor(DomainError e) => switch (e) {
    PinningError() => 'TrustPin validation failed: ${e.message}',
    NetworkError() => 'Connection failed: ${e.message}',
    ValidationError() => e.message,
    UnknownError() => 'Unexpected error: ${e.message}',
  };

  void _update(UiState Function(UiState) reducer) {
    _state = reducer(_state);
    notifyListeners();
  }
}
