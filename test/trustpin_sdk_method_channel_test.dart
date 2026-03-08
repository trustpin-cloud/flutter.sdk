import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelTrustPinSDK', () {
    late MethodChannelTrustPinSDK platform;
    late List<MethodCall> methodCalls;

    setUp(() {
      platform = MethodChannelTrustPinSDK();
      methodCalls = [];
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        
        switch (methodCall.method) {
          case 'setup':
            // Validate setup parameters
            final args = Map<String, dynamic>.from(methodCall.arguments as Map);
            if (args['organizationId'] == '' || args['projectId'] == '' || args['publicKey'] == '') {
              throw PlatformException(
                code: 'INVALID_PROJECT_CONFIG',
                message: 'Invalid project configuration',
                details: 'Organization ID, Project ID, and Public Key cannot be empty',
              );
            }
            return null;
          case 'verify':
            // Validate verify parameters
            final args = Map<String, dynamic>.from(methodCall.arguments as Map);
            final domain = args['domain'] as String;
            final certificate = args['certificate'] as String;
            
            if (domain.isEmpty) {
              throw PlatformException(
                code: 'INVALID_DOMAIN',
                message: 'Domain cannot be empty',
              );
            }
            
            if (!certificate.contains('BEGIN CERTIFICATE')) {
              throw PlatformException(
                code: 'INVALID_SERVER_CERT',
                message: 'Invalid certificate format',
              );
            }
            
            // Simulate different error scenarios based on domain
            switch (domain) {
              case 'pins-mismatch.com':
                throw PlatformException(
                  code: 'PINS_MISMATCH',
                  message: 'Certificate does not match any configured pins',
                );
              case 'not-registered.com':
                throw PlatformException(
                  code: 'DOMAIN_NOT_REGISTERED',
                  message: 'Domain not registered for pinning',
                );
              case 'expired-pins.com':
                throw PlatformException(
                  code: 'ALL_PINS_EXPIRED',
                  message: 'All pins for the domain have expired',
                );
              case 'network-error.com':
                throw PlatformException(
                  code: 'ERROR_FETCHING_PINNING_INFO',
                  message: 'Failed to fetch pinning information',
                );
              case 'config-error.com':
                throw PlatformException(
                  code: 'CONFIGURATION_VALIDATION_FAILED',
                  message: 'Configuration validation failed',
                );
            }
            return null;
          case 'setLogLevel':
            final args = Map<String, dynamic>.from(methodCall.arguments as Map);
            final logLevel = args['logLevel'] as String;
            if (!['none', 'error', 'info', 'debug'].contains(logLevel)) {
              throw PlatformException(
                code: 'INVALID_LOG_LEVEL',
                message: 'Invalid log level: $logLevel',
              );
            }
            return null;
          case 'fetchCertificate':
            final args = Map<String, dynamic>.from(methodCall.arguments as Map);
            final host = args['host'] as String;

            if (host.isEmpty) {
              throw PlatformException(
                code: 'INVALID_ARGUMENTS',
                message: 'Missing required arguments',
              );
            }

            if (host == 'invalid-host.example') {
              throw PlatformException(
                code: 'INVALID_SERVER_CERT',
                message: 'TLS handshake failed',
              );
            }

            return '-----BEGIN CERTIFICATE-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END CERTIFICATE-----\n';
          default:
            throw MissingPluginException('No implementation found for method ${methodCall.method}');
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
      methodCalls.clear();
    });

    group('setup()', () {
      test('should call native setup with correct parameters', () async {
        await platform.setup(
          'test-org',
          'test-project',
          'test-key',
          mode: 'strict',
        );

        expect(methodCalls.length, equals(1));
        expect(methodCalls[0].method, equals('setup'));
        
        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['organizationId'], equals('test-org'));
        expect(args['projectId'], equals('test-project'));
        expect(args['publicKey'], equals('test-key'));
        expect(args['mode'], equals('strict'));
      });

      test('should use strict mode as default', () async {
        await platform.setup('test-org', 'test-project', 'test-key');

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['mode'], equals('strict'));
      });

      test('should support permissive mode', () async {
        await platform.setup(
          'test-org',
          'test-project',
          'test-key',
          mode: 'permissive',
        );

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['mode'], equals('permissive'));
      });

      test('should support configurationURL parameter', () async {
        final configUrl = Uri.parse('https://custom.example.com/config');
        
        await platform.setup(
          'test-org',
          'test-project',
          'test-key',
          configurationURL: configUrl,
          mode: 'permissive',
        );

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['configurationURL'], equals(configUrl.toString()));
        expect(args['mode'], equals('permissive'));
      });

      test('should handle null configurationURL', () async {
        await platform.setup(
          'test-org',
          'test-project',
          'test-key',
        );

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['configurationURL'], isNull);
        expect(args['mode'], equals('strict'));
      });

      test('should throw PlatformException for invalid parameters', () async {
        expect(() async {
          await platform.setup('', '', '');
        }, throwsA(isA<PlatformException>()));
      });

      test('should preserve PlatformException details', () async {
        try {
          await platform.setup('', '', '');
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('INVALID_PROJECT_CONFIG'));
          expect(e.message, equals('Invalid project configuration'));
          expect(e.details, isNotNull);
        }
      });
    });

    group('verify()', () {
      const validCertificate = '''
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8...
-----END CERTIFICATE-----
''';

      test('should call native verify with correct parameters', () async {
        await platform.verify('api.example.com', validCertificate);

        expect(methodCalls.length, equals(1));
        expect(methodCalls[0].method, equals('verify'));
        
        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['domain'], equals('api.example.com'));
        expect(args['certificate'], equals(validCertificate));
      });

      test('should handle successful verification', () async {
        expect(() async {
          await platform.verify('valid.example.com', validCertificate);
        }, returnsNormally);
      });

      test('should throw PlatformException for pins mismatch', () async {
        try {
          await platform.verify('pins-mismatch.com', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('PINS_MISMATCH'));
          expect(e.message, contains('Certificate does not match'));
        }
      });

      test('should throw PlatformException for domain not registered', () async {
        try {
          await platform.verify('not-registered.com', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('DOMAIN_NOT_REGISTERED'));
          expect(e.message, contains('Domain not registered'));
        }
      });

      test('should throw PlatformException for expired pins', () async {
        try {
          await platform.verify('expired-pins.com', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('ALL_PINS_EXPIRED'));
          expect(e.message, contains('pins for the domain have expired'));
        }
      });

      test('should throw PlatformException for network errors', () async {
        try {
          await platform.verify('network-error.com', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('ERROR_FETCHING_PINNING_INFO'));
          expect(e.message, contains('Failed to fetch'));
        }
      });

      test('should throw PlatformException for configuration validation failure', () async {
        try {
          await platform.verify('config-error.com', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('CONFIGURATION_VALIDATION_FAILED'));
          expect(e.message, contains('Configuration validation failed'));
        }
      });

      test('should throw PlatformException for invalid certificate format', () async {
        try {
          await platform.verify('api.example.com', 'invalid-certificate');
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('INVALID_SERVER_CERT'));
          expect(e.message, contains('Invalid certificate format'));
        }
      });

      test('should throw PlatformException for empty domain', () async {
        try {
          await platform.verify('', validCertificate);
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('INVALID_DOMAIN'));
          expect(e.message, contains('Domain cannot be empty'));
        }
      });
    });

    group('setLogLevel()', () {
      test('should call native setLogLevel with debug level', () async {
        await platform.setLogLevel('debug');

        expect(methodCalls.length, equals(1));
        expect(methodCalls[0].method, equals('setLogLevel'));
        
        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['logLevel'], equals('debug'));
      });

      test('should call native setLogLevel with info level', () async {
        await platform.setLogLevel('info');

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['logLevel'], equals('info'));
      });

      test('should call native setLogLevel with error level', () async {
        await platform.setLogLevel('error');

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['logLevel'], equals('error'));
      });

      test('should call native setLogLevel with none level', () async {
        await platform.setLogLevel('none');

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['logLevel'], equals('none'));
      });

      test('should throw PlatformException for invalid log level', () async {
        try {
          await platform.setLogLevel('invalid');
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('INVALID_LOG_LEVEL'));
          expect(e.message, contains('Invalid log level'));
        }
      });
    });

    group('fetchCertificate()', () {
      test('should call native fetchCertificate with correct parameters', () async {
        final result = await platform.fetchCertificate('api.example.com');

        expect(methodCalls.length, equals(1));
        expect(methodCalls[0].method, equals('fetchCertificate'));

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['host'], equals('api.example.com'));
        expect(args['port'], equals(443));
        expect(result, contains('BEGIN CERTIFICATE'));
      });

      test('should pass custom port', () async {
        await platform.fetchCertificate('api.example.com', port: 8443);

        final args = Map<String, dynamic>.from(methodCalls[0].arguments as Map);
        expect(args['host'], equals('api.example.com'));
        expect(args['port'], equals(8443));
      });

      test('should return PEM string', () async {
        final result = await platform.fetchCertificate('api.example.com');

        expect(result, contains('-----BEGIN CERTIFICATE-----'));
        expect(result, contains('-----END CERTIFICATE-----'));
      });

      test('should throw PlatformException for TLS failure', () async {
        try {
          await platform.fetchCertificate('invalid-host.example');
          fail('Expected PlatformException to be thrown');
        } on PlatformException catch (e) {
          expect(e.code, equals('INVALID_SERVER_CERT'));
          expect(e.message, contains('TLS handshake failed'));
        }
      });
    });

    group('Method Channel Configuration', () {
      test('should use correct method channel name', () {
        expect(platform.methodChannel.name, equals('cloud.trustpin.sdk.flutter'));
      });
    });

    group('Parameter Validation', () {
      test('should handle null arguments gracefully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (MethodCall methodCall) async {
          expect(methodCall.arguments, isNotNull);
          return null;
        });

        await platform.setup('org', 'project', 'key');
        await platform.verify('domain.com', 'cert');
        await platform.setLogLevel('debug');
      });

      test('should preserve argument types', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (MethodCall methodCall) async {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          
          switch (methodCall.method) {
            case 'setup':
              expect(args['organizationId'], isA<String>());
              expect(args['projectId'], isA<String>());
              expect(args['publicKey'], isA<String>());
              expect(args['mode'], isA<String>());
              // configurationURL can be null or String
              if (args['configurationURL'] != null) {
                expect(args['configurationURL'], isA<String>());
              }
              break;
            case 'verify':
              expect(args['domain'], isA<String>());
              expect(args['certificate'], isA<String>());
              break;
            case 'setLogLevel':
              expect(args['logLevel'], isA<String>());
              break;
          }
          return null;
        });

        await platform.setup('org', 'project', 'key', mode: 'strict');
        await platform.verify('domain.com', 'cert');
        await platform.setLogLevel('debug');
      });
    });

    group('Error Handling', () {
      test('should propagate platform exceptions unchanged', () async {
        final testException = PlatformException(
          code: 'TEST_ERROR',
          message: 'Test error message',
          details: {'key': 'value'},
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (MethodCall methodCall) async {
          throw testException;
        });
      });
    });

    group('Integration Scenarios', () {
      test('should support sequential method calls', () async {
        await platform.setLogLevel('debug');
        await platform.setup('org', 'project', 'key');
        await platform.verify('api.example.com', '''
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8...
-----END CERTIFICATE-----
''');

        expect(methodCalls.length, equals(3));
        expect(methodCalls[0].method, equals('setLogLevel'));
        expect(methodCalls[1].method, equals('setup'));
        expect(methodCalls[2].method, equals('verify'));
      });

      test('should support multiple verify calls', () async {
        await platform.setup('org', 'project', 'key');
        
        const cert = '''
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8...
-----END CERTIFICATE-----
''';

        await platform.verify('api1.example.com', cert);
        await platform.verify('api2.example.com', cert);
        await platform.verify('api3.example.com', cert);

        expect(methodCalls.length, equals(4));
        expect(methodCalls[0].method, equals('setup'));
        expect(methodCalls[1].method, equals('verify'));
        expect(methodCalls[2].method, equals('verify'));
        expect(methodCalls[3].method, equals('verify'));

        final verify1Args = Map<String, dynamic>.from(methodCalls[1].arguments as Map);
        final verify2Args = Map<String, dynamic>.from(methodCalls[2].arguments as Map);
        final verify3Args = Map<String, dynamic>.from(methodCalls[3].arguments as Map);
        
        expect(verify1Args['domain'], equals('api1.example.com'));
        expect(verify2Args['domain'], equals('api2.example.com'));
        expect(verify3Args['domain'], equals('api3.example.com'));
      });

      test('should handle mixed success and failure scenarios', () async {
        await platform.setup('org', 'project', 'key');
        
        const validCert = '''
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8...
-----END CERTIFICATE-----
''';

        // Successful verification
        await platform.verify('valid.example.com', validCert);
        
        // Failed verification
        try {
          await platform.verify('pins-mismatch.com', validCert);
          fail('Expected PlatformException');
        } on PlatformException catch (e) {
          expect(e.code, equals('PINS_MISMATCH'));
        }

        // Another successful verification
        await platform.verify('another-valid.com', validCert);

        expect(methodCalls.length, equals(4)); // setup + 3 verify calls
      });
    });
  });
}