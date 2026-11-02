import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trustpin_attest/trustpin_attest.dart';
import 'package:trustpin_attest/trustpin_attest_method_channel.dart';
import 'package:trustpin_attest/trustpin_attest_platform_interface.dart';

class _FakePlatform extends TrustPinAttestPlatform
    with MockPlatformInterfaceMixin {
  final calls = <String, Map<String, Object?>>{};
  final stateController = StreamController<Map<Object?, Object?>>.broadcast();
  final eventController = StreamController<Map<Object?, Object?>>.broadcast();
  Map<Object?, Object?> currentState = const {'state': 'unavailable'};
  Object? error;

  Future<T> _record<T>(String name, Map<String, Object?> args, T value) {
    calls[name] = args;
    final e = error;
    return e == null ? Future.value(value) : Future.error(e);
  }

  @override
  Future<void> setup({
    required String verifierUrl,
    required List<String> attestedHosts,
    int? googleCloudProjectNumber,
    String? debugToken,
    String? instanceId,
  }) =>
      _record(
          'setup',
          {
            'verifierUrl': verifierUrl,
            'attestedHosts': attestedHosts,
            'googleCloudProjectNumber': googleCloudProjectNumber,
            'debugToken': debugToken,
            'instanceId': instanceId,
          },
          null);

  @override
  Future<void> prefetch({String? instanceId}) =>
      _record('prefetch', {'instanceId': instanceId}, null);

  @override
  Future<String> getToken({String? instanceId}) =>
      _record('getToken', {'instanceId': instanceId}, 'token');

  @override
  Future<Map<String, String>> attestationHeaders(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? instanceId,
  }) =>
      _record('attestationHeaders', {'url': url, 'headers': headers},
          {'TrustPin-Attestation': 'token'});

  @override
  Future<Map<String, String>> assertionHeaders(
    Uint8List payloadDigest, {
    String? instanceId,
  }) =>
      _record('assertionHeaders', {
        'payloadDigest': payloadDigest,
        'instanceId': instanceId,
      }, {
        'TrustPin-Attestation': 'token',
        'TrustPin-Assertion': 'assertion',
      });

  @override
  Future<void> reset({String? instanceId}) =>
      _record('reset', {'instanceId': instanceId}, null);

  @override
  Future<Map<Object?, Object?>> state({String? instanceId}) =>
      _record('state', {'instanceId': instanceId}, currentState);

  @override
  Stream<Map<Object?, Object?>> get stateEvents => stateController.stream;

  @override
  Stream<Map<Object?, Object?>> get events => eventController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;

  setUp(() {
    platform = _FakePlatform();
    TrustPinAttestPlatform.instance = platform;
  });

  group('setup', () {
    test('passes the configuration', () async {
      await TrustPinAttest.instance('lib').setup(TrustPinAttestConfiguration(
        verifierUrl: Uri.parse('https://attest.example.com'),
        attestedHosts: const ['api.example.com'],
        googleCloudProjectNumber: 123456789012,
        debugToken: 'debug',
      ));

      expect(platform.calls['setup'], {
        'verifierUrl': 'https://attest.example.com',
        'attestedHosts': ['api.example.com'],
        'googleCloudProjectNumber': 123456789012,
        'debugToken': 'debug',
        'instanceId': 'lib',
      });
    });

    test('maps platform errors to TrustPinAttestException', () async {
      platform.error = PlatformException(code: 'ALREADY_INITIALIZED');

      await expectLater(
        TrustPinAttest.shared.setup(TrustPinAttestConfiguration(
          verifierUrl: Uri.parse('https://attest.example.com'),
          attestedHosts: const ['api.example.com'],
        )),
        throwsA(isA<TrustPinAttestException>().having(
            (e) => e.isAlreadyInitialized, 'isAlreadyInitialized', true)),
      );
    });
  });

  group('never-throwing calls', () {
    test('prefetch swallows errors', () async {
      platform.error = PlatformException(code: 'NOT_SET_UP');

      await TrustPinAttest.shared.prefetch();
    });

    test('attestationHeaders swallows errors', () async {
      platform.error = PlatformException(code: 'ATTEST_ERROR');

      final headers = await TrustPinAttest.shared
          .attestationHeaders(Uri.parse('https://api.example.com/'));

      expect(headers, isEmpty);
    });

    test('attestationHeaders leaves the HTTPS rule to the native SDK',
        () async {
      await TrustPinAttest.shared
          .attestationHeaders(Uri.parse('http://api.example.com/'));

      expect(platform.calls['attestationHeaders']?['url'],
          'http://api.example.com/');
    });
  });

  group('assertionHeaders', () {
    test('passes the digest and returns both headers', () async {
      final digest = Uint8List(32);

      final headers =
          await TrustPinAttest.instance('lib').assertionHeaders(digest);

      expect(platform.calls['assertionHeaders'],
          {'payloadDigest': digest, 'instanceId': 'lib'});
      expect(headers.keys, [
        TrustPinAttest.headerName,
        TrustPinAttest.assertionHeaderName,
      ]);
    });

    test('maps an invalid digest', () async {
      platform.error = PlatformException(code: 'INVALID_DIGEST');

      await expectLater(
        TrustPinAttest.shared.assertionHeaders(Uint8List(3)),
        throwsA(isA<TrustPinAttestException>()
            .having((e) => e.isInvalidDigest, 'isInvalidDigest', true)),
      );
    });
  });

  group('reset', () {
    test('rethrows errors', () async {
      platform.error = PlatformException(code: 'ATTEST_ERROR');

      await expectLater(
        TrustPinAttest.shared.reset(),
        throwsA(isA<TrustPinAttestException>()),
      );
    });
  });

  group('state', () {
    test('decodes ready', () async {
      platform.currentState = {'state': 'ready', 'expiresAtMs': 1000};

      expect(
        await TrustPinAttest.shared.state,
        TrustPinAttestReady(
            DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true)),
      );
    });

    test('decodes failed with reasons and no retry time', () async {
      platform.currentState = {
        'state': 'failed',
        'code': 'ATTESTATION_FAILED',
        'message': 'AttestationFailed',
        'reasons': ['dev_environment'],
        'retryAtMs': null,
      };

      final state = await TrustPinAttest.shared.state;

      expect(state, isA<TrustPinAttestFailed>());
      final failed = state as TrustPinAttestFailed;
      expect(failed.error.isAttestationFailed, isTrue);
      expect(failed.error.reasons, ['dev_environment']);
      expect(failed.retryAt, isNull);
    });

    test('stateChanges emits the current state, then this instance\'s changes',
        () async {
      platform.currentState = {'state': 'unavailable'};
      final states = <TrustPinAttestState>[];
      final subscription =
          TrustPinAttest.shared.stateChanges.listen(states.add);
      await pumpEventQueue();

      platform.stateController
        ..add({'instanceId': 'other', 'state': 'attesting'})
        ..add({'instanceId': 'default', 'state': 'attesting'});
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, [
        const TrustPinAttestUnavailable(),
        const TrustPinAttestAttesting(),
      ]);
    });
  });

  group('events', () {
    test('decodes this instance\'s events and skips unknown ones', () async {
      final events = <TrustPinAttestEvent>[];
      final subscription = TrustPinAttest.shared.events.listen(events.add);

      platform.eventController
        ..add({'instanceId': 'other', 'event': 'keyGenerated'})
        ..add({'instanceId': 'default', 'event': 'keyGenerated'})
        ..add({'instanceId': 'default', 'event': 'somethingNew'})
        ..add({
          'instanceId': 'default',
          'event': 'attestationSucceeded',
          'durationMs': 850,
        })
        ..add({
          'instanceId': 'default',
          'event': 'attestationFailed',
          'reasons': ['app_not_allowed'],
          'retryAtMs': null,
        })
        ..add({
          'instanceId': 'default',
          'event': 'refreshFailed',
          'code': 'VERIFIER_INCOMPATIBLE',
          'message': 'VerifierIncompatible',
          'reasons': <String>[],
        })
        ..add(
            {'instanceId': 'default', 'event': 'waitEntered', 'untilMs': 1000});
      await pumpEventQueue();
      await subscription.cancel();

      expect(events, [
        const TrustPinAttestKeyGenerated(),
        const TrustPinAttestAttestationSucceeded(Duration(milliseconds: 850)),
        const TrustPinAttestAttestationFailed(['app_not_allowed'], null),
        const TrustPinAttestRefreshFailed(TrustPinAttestException(
            'VERIFIER_INCOMPATIBLE', 'VerifierIncompatible')),
        TrustPinAttestWaitEntered(
            DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true)),
      ]);
      expect(
          (events[3] as TrustPinAttestRefreshFailed)
              .error
              .isVerifierIncompatible,
          isTrue);
    });
  });

  group('TrustPinAttestException', () {
    test('carries the reasons from platform details', () {
      final error = TrustPinAttestException.fromPlatformException(
        PlatformException(
          code: 'ATTESTATION_FAILED',
          message: 'AttestationFailed',
          details: ['app_not_allowed'],
        ),
      );

      expect(error.code, 'ATTESTATION_FAILED');
      expect(error.reasons, ['app_not_allowed']);
    });
  });

  group('MethodChannelTrustPinAttest', () {
    test('sends the call arguments', () async {
      final channelPlatform = MethodChannelTrustPinAttest();
      final received = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelPlatform.methodChannel,
              (call) async {
        received.add(call);
        if (call.method == 'attestationHeaders') {
          return {'TrustPin-Attestation': 'token'};
        }
        return null;
      });

      await channelPlatform.bindToHeader('Authorization', instanceId: 'lib');
      final headers = await channelPlatform.attestationHeaders(
        'https://api.example.com/',
        headers: {'Authorization': 'Bearer abc'},
      );

      expect(received.first.method, 'bindToHeader');
      expect(received.first.arguments,
          {'name': 'Authorization', 'instanceId': 'lib'});
      expect(received.last.arguments, {
        'url': 'https://api.example.com/',
        'method': 'GET',
        'headers': {'Authorization': 'Bearer abc'},
        'instanceId': null,
      });
      expect(headers, {'TrustPin-Attestation': 'token'});
    });

    test('sends the payload digest as bytes', () async {
      final channelPlatform = MethodChannelTrustPinAttest();
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channelPlatform.methodChannel,
              (call) async {
        received = call;
        return {'TrustPin-Assertion': 'assertion'};
      });
      final digest = Uint8List.fromList(List.filled(32, 7));

      final headers = await channelPlatform.assertionHeaders(digest);

      expect(received?.method, 'assertionHeaders');
      expect(
          received?.arguments, {'payloadDigest': digest, 'instanceId': null});
      expect(headers, {'TrustPin-Assertion': 'assertion'});
    });
  });
}
