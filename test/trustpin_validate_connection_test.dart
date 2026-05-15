import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';
import 'package:trustpin_sdk/trustpin_sdk_platform_interface.dart';

class _RecordingPlatform extends TrustPinSDKPlatform
    with MockPlatformInterfaceMixin {
  final List<_ValidateCall> calls = [];

  /// Optional override: when set, validateConnection throws this exception
  /// instead of completing successfully.
  Object? throwOnValidate;

  @override
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
  }) =>
      Future.value();

  @override
  Future<void> verify(String domain, String certificate,
          {String? instanceId}) =>
      Future.value();

  @override
  Future<void> setLogLevel(String logLevel, {String? instanceId}) =>
      Future.value();

  @override
  Future<String> fetchCertificate(String host,
          {int port = 443, int? timeoutMs, String? instanceId}) =>
      Future.value('mock-pem');

  @override
  Future<void> validateConnection(
    String host, {
    int port = 443,
    int? timeoutMs,
    String? instanceId,
  }) {
    calls.add(_ValidateCall(host, port, timeoutMs, instanceId));
    final err = throwOnValidate;
    if (err != null) {
      return Future.error(err);
    }
    return Future.value();
  }
}

class _ValidateCall {
  final String host;
  final int port;
  final int? timeoutMs;
  final String? instanceId;
  _ValidateCall(this.host, this.port, this.timeoutMs, this.instanceId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPin.validateConnection', () {
    late _RecordingPlatform mock;

    setUp(() {
      mock = _RecordingPlatform();
      TrustPinSDKPlatform.instance = mock;
    });

    test('forwards default port and null timeout/instanceId for shared',
        () async {
      await TrustPin.shared.validateConnection('api.example.com');

      expect(mock.calls, hasLength(1));
      expect(mock.calls.single.host, 'api.example.com');
      expect(mock.calls.single.port, 443);
      expect(mock.calls.single.timeoutMs, isNull);
      expect(mock.calls.single.instanceId, isNull);
    });

    test('converts Duration timeout to milliseconds', () async {
      await TrustPin.shared.validateConnection(
        'api.example.com',
        timeout: const Duration(seconds: 7),
      );

      expect(mock.calls.single.timeoutMs, 7000);
    });

    test('forwards custom port', () async {
      await TrustPin.shared.validateConnection(
        'api.example.com',
        port: 8443,
      );

      expect(mock.calls.single.port, 8443);
    });

    test('forwards instanceId for named instances', () async {
      final named = TrustPin.instance('lib.networking');
      await named.validateConnection('api.example.com');

      expect(mock.calls.single.instanceId, 'lib.networking');
    });

    test('omits instanceId for the shared instance', () async {
      await TrustPin.shared.validateConnection('api.example.com');

      expect(mock.calls.single.instanceId, isNull);
    });

    test('returns normally when platform completes successfully', () {
      expect(
        () async => TrustPin.shared.validateConnection('api.example.com'),
        returnsNormally,
      );
    });

    test('wraps PlatformException as TrustPinException with same code',
        () async {
      mock.throwOnValidate = PlatformException(
        code: 'PINS_MISMATCH',
        message: 'no match',
      );

      try {
        await TrustPin.shared.validateConnection('api.example.com');
        fail('Expected TrustPinException');
      } on TrustPinException catch (e) {
        expect(e.code, 'PINS_MISMATCH');
        expect(e.isPinsMismatch, isTrue);
      }
    });

    test('maps FETCH_CERTIFICATE_TIMEOUT through isFetchCertificateTimeout',
        () async {
      mock.throwOnValidate = PlatformException(
        code: 'FETCH_CERTIFICATE_TIMEOUT',
        message: 'timed out',
      );

      try {
        await TrustPin.shared.validateConnection(
          'api.example.com',
          timeout: const Duration(milliseconds: 1),
        );
        fail('Expected TrustPinException');
      } on TrustPinException catch (e) {
        expect(e.isFetchCertificateTimeout, isTrue);
      }
    });

    test('preserves VALIDATE_CONNECTION_ERROR code on generic failures',
        () async {
      mock.throwOnValidate = PlatformException(
        code: 'VALIDATE_CONNECTION_ERROR',
        message: 'something went wrong',
      );

      try {
        await TrustPin.shared.validateConnection('api.example.com');
        fail('Expected TrustPinException');
      } on TrustPinException catch (e) {
        expect(e.code, 'VALIDATE_CONNECTION_ERROR');
      }
    });
  });
}
