import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';
import 'package:trustpin_sdk/trustpin_sdk_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPinLogEvent.fromMap', () {
    test('decodes each wire level', () {
      for (final (wire, expected) in [
        ('error', TrustPinLogLevel.error),
        ('info', TrustPinLogLevel.info),
        ('debug', TrustPinLogLevel.debug),
      ]) {
        final event = TrustPinLogEvent.fromMap({
          'level': wire,
          'instanceId': 'default',
          'message': 'hello',
        });
        expect(event.level, expected, reason: 'wire level $wire');
        expect(event.instanceId, 'default');
        expect(event.message, 'hello');
      }
    });

    test('falls back to info for unknown or missing levels', () {
      expect(
        TrustPinLogEvent.fromMap({'level': 'verbose', 'message': 'm'}).level,
        TrustPinLogLevel.info,
      );
      expect(
        TrustPinLogEvent.fromMap({'message': 'm'}).level,
        TrustPinLogLevel.info,
      );
    });

    test('toString includes level, instance, and message', () {
      const event = TrustPinLogEvent(
        level: TrustPinLogLevel.debug,
        instanceId: 'com.mylib.networking',
        message: 'refreshed configuration',
      );

      expect(event.toString(), contains('debug'));
      expect(event.toString(), contains('com.mylib.networking'));
      expect(event.toString(), contains('refreshed configuration'));
    });
  });

  group('MethodChannelTrustPinSDK.logEvents', () {
    test('forwards event maps from the platform event channel', () async {
      final platform = MethodChannelTrustPinSDK();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        platform.logEventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'level': 'info',
              'instanceId': 'default',
              'message': 'configuration loaded',
            });
            events.endOfStream();
          },
        ),
      );

      final received = await platform.logEvents.first;

      expect(received['level'], 'info');
      expect(received['message'], 'configuration loaded');
    });

    test('uses the documented channel name', () {
      expect(
        MethodChannelTrustPinSDK().logEventChannel.name,
        'cloud.trustpin.sdk.flutter/log_events',
      );
    });
  });

  group('TrustPin.logs', () {
    test('maps platform maps into typed events', () async {
      final previous = TrustPinSDKPlatform.instance;
      TrustPinSDKPlatform.instance = _FakeLogEventsPlatform();
      addTearDown(() => TrustPinSDKPlatform.instance = previous);

      final events = await TrustPin.logs.take(2).toList();

      expect(events[0].level, TrustPinLogLevel.error);
      expect(events[0].message, 'pin mismatch for api.example.com');
      expect(events[1].level, TrustPinLogLevel.debug);
      expect(events[1].instanceId, 'com.mylib.networking');
    });
  });
}

class _FakeLogEventsPlatform extends TrustPinSDKPlatform {
  @override
  Stream<Map<Object?, Object?>> get logEvents => Stream.fromIterable([
        {
          'level': 'error',
          'instanceId': 'default',
          'message': 'pin mismatch for api.example.com',
        },
        {
          'level': 'debug',
          'instanceId': 'com.mylib.networking',
          'message': 'configuration refresh scheduled',
        },
      ]);
}
