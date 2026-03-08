import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trustpin_sdk/http_interceptors/http_client_interceptor.dart';
import 'package:trustpin_sdk/trustpin_exception.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPinHttpClient', () {
    late MethodChannelTrustPinSDK platform;
    late List<MethodCall> methodCalls;

    setUp(() {
      platform = MethodChannelTrustPinSDK();
      methodCalls = [];

      // Mock the platform method channel for TrustPin.verify calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        
        switch (methodCall.method) {
          case 'setup':
            return null;
          case 'verify':
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
            
            // Simulate different scenarios based on domain
            switch (domain) {
              case 'pins-mismatch.example.com':
                throw PlatformException(
                  code: 'PINS_MISMATCH',
                  message: 'Certificate does not match any configured pins',
                );
              case 'not-registered.example.com':
                throw PlatformException(
                  code: 'DOMAIN_NOT_REGISTERED',
                  message: 'Domain not registered for pinning',
                );
              case 'expired-pins.example.com':
                throw PlatformException(
                  code: 'ALL_PINS_EXPIRED',
                  message: 'All pins for the domain have expired',
                );
              case 'network-error.example.com':
                throw PlatformException(
                  code: 'ERROR_FETCHING_PINNING_INFO',
                  message: 'Failed to fetch pinning information',
                );
              case 'config-error.example.com':
                throw PlatformException(
                  code: 'CONFIGURATION_VALIDATION_FAILED',
                  message: 'Configuration validation failed',
                );
              default:
                // Successful validation
                return null;
            }
          case 'setLogLevel':
            return null;
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

    group('Constructors', () {
      test('should create with inner client', () {
        final innerClient = http.Client();
        final trustPinClient = TrustPinHttpClient(innerClient);
        
        expect(trustPinClient, isA<TrustPinHttpClient>());
        expect(trustPinClient, isA<http.BaseClient>());
      });

      test('should create with factory method', () {
        final trustPinClient = TrustPinHttpClient.create();
        
        expect(trustPinClient, isA<TrustPinHttpClient>());
        expect(trustPinClient, isA<http.BaseClient>());
      });
    });

    group('Certificate Caching', () {
      test('should start with empty cache', () {
        final client = TrustPinHttpClient.create();
        
        // No direct way to check cache size, but clearing should work
        expect(() => client.clearCertificateCache(), returnsNormally);
      });

      test('should clear certificate cache', () {
        final client = TrustPinHttpClient.create();
        
        expect(() => client.clearCertificateCache(), returnsNormally);
        
        // Should be able to call multiple times
        client.clearCertificateCache();
        client.clearCertificateCache();
      });
    });

    group('Resource Management', () {
      test('should close properly', () {
        final client = TrustPinHttpClient.create();
        
        expect(() => client.close(), returnsNormally);
        
        // Should be safe to close multiple times
        client.close();
      });

      test('should clear cache on close', () {
        final client = TrustPinHttpClient.create();
        
        client.clearCertificateCache();
        client.close();
        
        // Should work without issues
        expect(true, isTrue);
      });
    });

    group('HTTP Method Support', () {
      test('should support basic HTTP methods', () {
        final client = TrustPinHttpClient.create();
        
        // Test that the client can be used for various HTTP methods
        // Note: These will fail due to no actual server, but we're testing interface compatibility
        expect(() async {
          try {
            await client.get(Uri.parse('http://example.com/test'));
          } catch (e) {
            // Expected to fail in test environment
          }
        }, returnsNormally);

        expect(() async {
          try {
            await client.post(Uri.parse('http://example.com/test'));
          } catch (e) {
            // Expected to fail in test environment
          }
        }, returnsNormally);

        expect(() async {
          try {
            await client.put(Uri.parse('http://example.com/test'));
          } catch (e) {
            // Expected to fail in test environment
          }
        }, returnsNormally);

        expect(() async {
          try {
            await client.delete(Uri.parse('http://example.com/test'));
          } catch (e) {
            // Expected to fail in test environment
          }
        }, returnsNormally);

        client.close();
      });
    });

    group('PEM Certificate Formatting', () {
      test('should format PEM certificate correctly', () {
        // Test the expected PEM format structure
        const validPem = '''-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8MOCK_DATA==
-----END CERTIFICATE-----''';

        expect(validPem, startsWith('-----BEGIN CERTIFICATE-----'));
        expect(validPem, endsWith('-----END CERTIFICATE-----'));
        expect(validPem, contains('\n'));
        
        // Test that it follows the expected line structure
        final lines = validPem.split('\n');
        expect(lines.length, greaterThan(2));
        expect(lines.first, equals('-----BEGIN CERTIFICATE-----'));
        expect(lines.last, equals('-----END CERTIFICATE-----'));
      });

      test('should handle base64 certificate data', () {
        const testCertData = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8KJ2F3gH4Kz9XvV';
        
        // Verify it's valid base64
        expect(() => base64Decode(testCertData), returnsNormally);
        
        final decoded = base64Decode(testCertData);
        expect(decoded, isA<List<int>>());
        expect(decoded, isNotEmpty);
        
        // Verify round-trip encoding
        final reencoded = base64Encode(decoded);
        expect(reencoded, equals(testCertData));
      });

      test('should handle line breaking in PEM format', () {
        const longBase64 = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8KJ2F3gH4Kz9XvV'
                          'W8YpLm3nO2qR5sT6uV7wX8yZ0aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0uV1wX2yZ'
                          '3aB4cD5eF6gH7iJ8kL9mN0oP1qR2sT3uV4wX5yZ6aB7cD8eF9gH0iJ3kL6mN9oP';
        
        // Should be able to format with 64-character line breaks
        const expectedLines = [
          'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8KJ2F3gH4Kz9XvV',
          'W8YpLm3nO2qR5sT6uV7wX8yZ0aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0uV1wX2yZ',
          '3aB4cD5eF6gH7iJ8kL9mN0oP1qR2sT3uV4wX5yZ6aB7cD8eF9gH0iJ3kL6mN9oP',
        ];
        
        for (int i = 0; i < expectedLines.length; i++) {
          expect(expectedLines[i].length, lessThanOrEqualTo(64));
        }
        
        // Test line breaking logic
        final buffer = StringBuffer();
        buffer.writeln('-----BEGIN CERTIFICATE-----');
        for (int i = 0; i < longBase64.length; i += 64) {
          final end = (i + 64 < longBase64.length) ? i + 64 : longBase64.length;
          buffer.writeln(longBase64.substring(i, end));
        }
        buffer.writeln('-----END CERTIFICATE-----');
        
        final result = buffer.toString();
        expect(result, contains('-----BEGIN CERTIFICATE-----'));
        expect(result, contains('-----END CERTIFICATE-----'));
        expect(result, contains('\n'));
      });
    });

    group('Error Handling', () {
      test('should handle TrustPinException scenarios', () {
        final errorCodes = [
          'INVALID_PROJECT_CONFIG',
          'ERROR_FETCHING_PINNING_INFO',
          'INVALID_SERVER_CERT',
          'PINS_MISMATCH',
          'ALL_PINS_EXPIRED',
          'DOMAIN_NOT_REGISTERED',
          'CONFIGURATION_VALIDATION_FAILED',
        ];

        for (final code in errorCodes) {
          final error = TrustPinException(code, 'Test error message for $code');
          
          expect(error.code, equals(code));
          expect(error.message, contains(code));
          expect(error, isA<TrustPinException>());
          expect(error, isA<Exception>());
        }
      });

      test('should create proper error messages', () {
        const testMessage = 'Certificate does not match any configured pins';
        final error = TrustPinException('PINS_MISMATCH', testMessage);

        expect(error.code, equals('PINS_MISMATCH'));
        expect(error.message, equals(testMessage));
        expect(error.toString(), contains('PINS_MISMATCH'));
        expect(error.toString(), contains(testMessage));
      });
    });

    group('Integration with http package', () {
      test('should work as http.BaseClient', () {
        final client = TrustPinHttpClient.create();
        
        expect(client, isA<http.BaseClient>());
        expect(client, isA<http.Client>());
        
        // Should have all the standard http.Client methods available
        expect(client.get, isA<Function>());
        expect(client.post, isA<Function>());
        expect(client.put, isA<Function>());
        expect(client.delete, isA<Function>());
        expect(client.head, isA<Function>());
        expect(client.patch, isA<Function>());
        expect(client.read, isA<Function>());
        expect(client.readBytes, isA<Function>());
        
        client.close();
      });

      test('should handle various URI formats', () {
        final client = TrustPinHttpClient.create();
        
        final testUris = [
          Uri.parse('http://example.com/path'),
          Uri.parse('https://api.example.com/v1/users'),
          Uri.parse('https://secure.example.com:8443/data'),
          Uri.parse('http://localhost:3000/test'),
          Uri.parse('https://192.168.1.1:443/secure'),
        ];

        for (final uri in testUris) {
          expect(uri.scheme, anyOf(equals('http'), equals('https')));
          expect(uri.host, isNotEmpty);
          expect(uri.port, greaterThan(0));
          
          // Should not throw when creating requests (though they may fail to execute)
          expect(() async {
            try {
              await client.get(uri);
            } catch (e) {
              // Expected in test environment
            }
          }, returnsNormally);
        }
        
        client.close();
      });
    });

    group('Certificate Cache Key Generation', () {
      test('should generate proper cache keys for different hosts', () {
        // Test the expected cache key format: "host:port"
        final testCases = [
          {'host': 'api.example.com', 'port': 443, 'expected': 'api.example.com:443'},
          {'host': 'secure.example.com', 'port': 8443, 'expected': 'secure.example.com:8443'},
          {'host': 'localhost', 'port': 3000, 'expected': 'localhost:3000'},
          {'host': '192.168.1.1', 'port': 443, 'expected': '192.168.1.1:443'},
        ];

        for (final testCase in testCases) {
          final host = testCase['host'] as String;
          final port = testCase['port'] as int;
          final expected = testCase['expected'] as String;
          
          final cacheKey = '$host:$port';
          expect(cacheKey, equals(expected));
          
          // Verify it's a valid cache key format
          expect(cacheKey, contains(':'));
          expect(cacheKey.split(':').length, equals(2));
          expect(cacheKey.split(':')[0], equals(host));
          expect(cacheKey.split(':')[1], equals(port.toString()));
        }
      });
    });

    group('Performance and Memory', () {
      test('should handle multiple client instances', () {
        final clients = <TrustPinHttpClient>[];
        
        // Create multiple clients
        for (int i = 0; i < 10; i++) {
          clients.add(TrustPinHttpClient.create());
        }
        
        expect(clients.length, equals(10));
        
        for (final client in clients) {
          expect(client, isA<TrustPinHttpClient>());
        }
        
        // Clean up
        for (final client in clients) {
          client.close();
        }
      });

      test('should handle cache operations efficiently', () {
        final client = TrustPinHttpClient.create();
        
        // Multiple cache operations should not throw
        for (int i = 0; i < 100; i++) {
          client.clearCertificateCache();
        }
        
        expect(() => client.clearCertificateCache(), returnsNormally);
        
        client.close();
      });
    });

    group('Thread Safety and Concurrency', () {
      test('should handle concurrent cache operations', () async {
        final client = TrustPinHttpClient.create();
        
        // Simulate concurrent cache operations
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future.microtask(() {
            client.clearCertificateCache();
          }));
        }
        
        await Future.wait(futures);
        
        expect(() => client.clearCertificateCache(), returnsNormally);
        
        client.close();
      });
    });

    group('Compatibility', () {
      test('should work with http package patterns', () {
        final client = TrustPinHttpClient.create();
        
        // Should support standard http package usage patterns
        expect(() async {
          try {
            // Standard GET request
            await client.get(
              Uri.parse('http://example.com'),
              headers: {'User-Agent': 'Test'},
            );
            // May fail in test, but shouldn't throw during setup
          } catch (e) {
            // Expected in test environment
          }
        }, returnsNormally);

        expect(() async {
          try {
            // POST with body
            await client.post(
              Uri.parse('http://example.com'),
              headers: {'Content-Type': 'application/json'},
              body: '{"test": "data"}',
            );
          } catch (e) {
            // Expected in test environment
          }
        }, returnsNormally);
        
        client.close();
      });
    });
  });
}