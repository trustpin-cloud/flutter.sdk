import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';
import 'package:trustpin_sdk/trustpin_sdk_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPinValidationEvent.fromMap', () {
    test('decodes a failure event', () {
      final event = TrustPinValidationEvent.fromMap({
        'instanceId': 'default',
        'domain': 'api.example.com',
        'code': 'PINS_MISMATCH',
        'message': 'Certificate does not match any configured pins',
        'certificatePem':
            '-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----',
      });

      expect(event.isFailure, isTrue);
      expect(event.isSuccess, isFalse);
      expect(event.instanceId, 'default');
      expect(event.domain, 'api.example.com');
      expect(event.error, isNotNull);
      expect(event.error!.isPinsMismatch, isTrue);
      expect(event.error!.message,
          'Certificate does not match any configured pins');
      expect(event.certificatePem, contains('BEGIN CERTIFICATE'));
    });

    test('decodes a success event (null code, no certificate)', () {
      final event = TrustPinValidationEvent.fromMap({
        'instanceId': 'com.mylib.networking',
        'domain': 'api.example.com',
        'code': null,
      });

      expect(event.isSuccess, isTrue);
      expect(event.isFailure, isFalse);
      expect(event.instanceId, 'com.mylib.networking');
      expect(event.error, isNull);
      expect(event.certificatePem, isNull);
    });

    test('decodes a success event with the code key absent entirely', () {
      // The iOS side omits the key rather than sending an explicit null.
      final event = TrustPinValidationEvent.fromMap({
        'instanceId': 'default',
        'domain': 'api.example.com',
      });

      expect(event.isSuccess, isTrue);
    });

    test('toString names the verdict and omits the certificate', () {
      final failure = TrustPinValidationEvent.fromMap({
        'instanceId': 'default',
        'domain': 'evil.example.com',
        'code': 'DOMAIN_NOT_REGISTERED',
        'certificatePem': 'SENSITIVE',
      });

      expect(failure.toString(), contains('failure'));
      expect(failure.toString(), contains('DOMAIN_NOT_REGISTERED'));
      expect(failure.toString(), isNot(contains('SENSITIVE')));
    });
  });

  group('MethodChannelTrustPinSDK.validationEvents', () {
    test('forwards event maps from the platform event channel', () async {
      final platform = MethodChannelTrustPinSDK();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        platform.eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'instanceId': 'default',
              'domain': 'api.example.com',
              'code': 'PINS_MISMATCH',
              'message': 'mismatch',
              'certificatePem': 'PEM',
            });
            events.success({
              'instanceId': 'default',
              'domain': 'ok.example.com',
              'code': null,
            });
            events.endOfStream();
          },
        ),
      );

      final received = await platform.validationEvents.take(2).toList();

      expect(received, hasLength(2));
      expect(received[0]['code'], 'PINS_MISMATCH');
      expect(received[0]['domain'], 'api.example.com');
      expect(received[1]['code'], isNull);
      expect(received[1]['domain'], 'ok.example.com');
    });

    test('uses the documented channel name', () {
      expect(
        MethodChannelTrustPinSDK().eventChannel.name,
        'cloud.trustpin.sdk.flutter/validation_events',
      );
    });
  });

  group('TrustPin.validationEvents', () {
    test('maps platform maps into typed events', () async {
      final previous = TrustPinSDKPlatform.instance;
      TrustPinSDKPlatform.instance = _FakeValidationEventsPlatform();
      addTearDown(() => TrustPinSDKPlatform.instance = previous);

      final events = await TrustPin.validationEvents.take(2).toList();

      expect(events[0].isFailure, isTrue);
      expect(events[0].error!.isAllPinsExpired, isTrue);
      expect(events[1].isSuccess, isTrue);
      expect(events[1].instanceId, 'default');
    });
  });

  group('TrustPinException Android-only getters', () {
    test('match their codes exactly', () {
      final cases = {
        'SETUP_IN_PROGRESS': (TrustPinException e) => e.isSetupInProgress,
        'LOCK_TIMEOUT': (TrustPinException e) => e.isLockTimeout,
        'SSL_CONTEXT_SETUP_FAILED': (TrustPinException e) =>
            e.isSslContextSetupFailed,
        'UNSUPPORTED_DEVICE': (TrustPinException e) => e.isUnsupportedDevice,
      };

      cases.forEach((code, getter) {
        expect(getter(TrustPinException(code, 'msg')), isTrue,
            reason: '$code getter must return true for its own code');
        expect(getter(const TrustPinException('INVALID_PROJECT_CONFIG', '')),
            isFalse,
            reason: '$code getter must return false for other codes');
      });
    });
  });
}

class _FakeValidationEventsPlatform extends TrustPinSDKPlatform {
  @override
  Stream<Map<Object?, Object?>> get validationEvents => Stream.fromIterable([
        {
          'instanceId': 'default',
          'domain': 'api.example.com',
          'code': 'ALL_PINS_EXPIRED',
          'message': 'expired',
          'certificatePem': 'PEM',
        },
        {
          'instanceId': 'default',
          'domain': 'api.example.com',
          'code': null,
        },
      ]);
}
