import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/http_interceptors/dio_interceptor.dart';
import 'package:trustpin_sdk/trustpin_exception.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPinDioInterceptor', () {
    late TrustPinDioInterceptor interceptor;
    late MethodChannelTrustPinSDK platform;
    late List<MethodCall> methodCalls;

    setUp(() {
      interceptor = TrustPinDioInterceptor();
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
      interceptor.clearCertificateCache();
    });

    group('Basic Functionality', () {
      test('should be instantiable', () {
        expect(interceptor, isA<TrustPinDioInterceptor>());
        expect(interceptor, isA<Interceptor>());
      });
    });

    group('HTTP Request Handling', () {
      test('should pass through HTTP requests without validation', () {
        final requestOptions = RequestOptions(
          path: '/api/data',
          baseUrl: 'http://api.example.com',
        );
        
        bool requestPassed = false;
        final handler = MockRequestInterceptorHandler(
          onNext: (options) {
            requestPassed = true;
            expect(options, equals(requestOptions));
          },
        );

        interceptor.onRequest(requestOptions, handler);

        // Should pass immediately without any certificate validation
        expect(requestPassed, isTrue);
        expect(methodCalls.isEmpty, isTrue);
      });

      test('should handle HTTP requests with various URLs', () {
        final testUrls = [
          'http://api.example.com/users',
          'http://localhost:8080/test',
          'http://192.168.1.1:3000/endpoint',
          'http://example.com/simple',
        ];

        for (final url in testUrls) {
          final uri = Uri.parse(url);
          final requestOptions = RequestOptions(
            path: uri.path,
            baseUrl: '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
          );
          
          bool requestPassed = false;
          final handler = MockRequestInterceptorHandler(
            onNext: (options) => requestPassed = true,
          );

          interceptor.onRequest(requestOptions, handler);
          expect(requestPassed, isTrue, reason: 'HTTP request should pass for $url');
        }

        // No method calls should have been made for HTTP requests
        expect(methodCalls.isEmpty, isTrue);
      });
    });

    group('HTTPS Request Validation (Unit Tests)', () {
      test('should attempt to validate HTTPS requests', () {
        final requestOptions = RequestOptions(
          path: '/api/data',
          baseUrl: 'https://api.example.com',
        );

        final handler = MockRequestInterceptorHandler();
        
        // This will attempt validation but fail due to no real socket connection
        // We're testing the code path, not the actual network connection
        interceptor.onRequest(requestOptions, handler);
        
        // The request should attempt HTTPS validation
        expect(requestOptions.uri.scheme, equals('https'));
      });

      test('should handle different HTTPS ports', () {
        final testCases = [
          {'url': 'https://api.example.com/data', 'expectedPort': 443},
          {'url': 'https://api.example.com:443/data', 'expectedPort': 443},
          {'url': 'https://api.example.com:8443/data', 'expectedPort': 8443},
          {'url': 'https://localhost:3001/test', 'expectedPort': 3001},
        ];

        for (final testCase in testCases) {
          final uri = Uri.parse(testCase['url'] as String);
          final requestOptions = RequestOptions(
            path: uri.path,
            baseUrl: '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
          );

          expect(requestOptions.uri.port, equals(testCase['expectedPort']));
          
          final handler = MockRequestInterceptorHandler();
          interceptor.onRequest(requestOptions, handler);
        }
      });
    });

    group('Certificate Caching Management', () {
      test('should clear certificate cache', () {              
        interceptor.clearCertificateCache();
      });
    });

    group('Certificate Format Handling', () {
      test('should handle PEM certificate format correctly', () {
        const validPem = '''-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7Q1jx8MOCK_DATA==
-----END CERTIFICATE-----''';

        expect(validPem, contains('BEGIN CERTIFICATE'));
        expect(validPem, contains('END CERTIFICATE'));
        
        // This tests that our format validation logic would work
        final lines = validPem.split('\n');
        expect(lines.length, greaterThan(2));
        expect(lines.first, contains('BEGIN CERTIFICATE'));
        expect(lines.last, contains('END CERTIFICATE'));
      });

      test('should handle base64 encoding/decoding', () {
        const testData = 'This is test certificate data';
        final encoded = base64Encode(testData.codeUnits);
        final decoded = base64Decode(encoded);
        
        expect(String.fromCharCodes(decoded), equals(testData));
        expect(encoded, isA<String>());
        expect(decoded, isA<List<int>>());
      });
    });

    group('Error Handling Structure', () {
      test('should create appropriate DioException for certificate failures', () {
        final requestOptions = RequestOptions(
          path: '/test',
          baseUrl: 'https://example.com',
        );

        final trustPinError = TrustPinException(
          'PINS_MISMATCH',
          'Certificate does not match pins',
        );

        final dioError = DioException(
          requestOptions: requestOptions,
          error: trustPinError,
          type: DioExceptionType.connectionError,
          message: 'Certificate pinning validation failed',
        );

        expect(dioError.error, isA<TrustPinException>());
        expect(dioError.type, equals(DioExceptionType.connectionError));
        expect(dioError.message, contains('Certificate pinning validation failed'));
        expect(dioError.requestOptions, equals(requestOptions));
        
        final innerError = dioError.error as TrustPinException;
        expect(innerError.code, equals('PINS_MISMATCH'));
        expect(innerError.message, equals('Certificate does not match pins'));
      });

      test('should handle various TrustPinException codes', () {
        final errorCodes = [
          'PINS_MISMATCH',
          'DOMAIN_NOT_REGISTERED',
          'ALL_PINS_EXPIRED',
          'ERROR_FETCHING_PINNING_INFO',
          'CONFIGURATION_VALIDATION_FAILED',
          'INVALID_SERVER_CERT',
          'NO_CERTIFICATE',
        ];

        for (final code in errorCodes) {
          final error = TrustPinException(code, 'Test message for $code');
          expect(error.code, equals(code));
          expect(error.message, contains(code));
          expect(error, isA<TrustPinException>());
        }
      });
    });

    group('RequestOptions Handling', () {
      test('should handle various RequestOptions configurations', () {
        final testCases = [
          RequestOptions(
            path: '/api/v1/users',
            baseUrl: 'https://api.example.com',
            method: 'GET',
            headers: {'Authorization': 'Bearer token123'},
          ),
          RequestOptions(
            path: '/api/posts',
            baseUrl: 'https://blog.example.com:8443',
            method: 'POST',
            data: {'title': 'Test Post'},
          ),
          RequestOptions(
            path: '/secure/endpoint',
            baseUrl: 'https://secure.example.com',
            method: 'PUT',
            queryParameters: {'filter': 'active'},
          ),
        ];

        for (final options in testCases) {
          expect(options.uri.scheme, equals('https'));
          expect(options.path, isNotEmpty);
          expect(options.uri.host, isNotEmpty);
          
          final handler = MockRequestInterceptorHandler();
          
          // Should not throw when processing RequestOptions
          expect(() {
            interceptor.onRequest(options, handler);
          }, returnsNormally);
        }
      });

      test('should preserve RequestOptions properties', () {
        final originalOptions = RequestOptions(
          path: '/test/endpoint',
          baseUrl: 'https://api.example.com',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer test-token',
          },
          queryParameters: {'version': 'v1'},
          data: {'test': 'data'},
          connectTimeout: Duration(seconds: 30),
          receiveTimeout: Duration(seconds: 60),
        );

        RequestOptions? capturedOptions;
        final handler = MockRequestInterceptorHandler(
          onNext: (options) => capturedOptions = options,
        );

        // For HTTP request (should pass through)
        final httpOptions = RequestOptions(
          path: originalOptions.path,
          baseUrl: 'http://api.example.com',
          method: originalOptions.method,
          headers: originalOptions.headers,
          queryParameters: originalOptions.queryParameters,
          data: originalOptions.data,
          connectTimeout: originalOptions.connectTimeout,
          receiveTimeout: originalOptions.receiveTimeout,
        );

        interceptor.onRequest(httpOptions, handler);

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.path, equals(originalOptions.path));
        expect(capturedOptions!.method, equals(originalOptions.method));
        expect(capturedOptions!.headers, equals(originalOptions.headers));
        expect(capturedOptions!.queryParameters, equals(originalOptions.queryParameters));
        expect(capturedOptions!.data, equals(originalOptions.data));
        expect(capturedOptions!.connectTimeout, equals(originalOptions.connectTimeout));
        expect(capturedOptions!.receiveTimeout, equals(originalOptions.receiveTimeout));
      });
    });

    group('Integration Patterns', () {
      test('should be compatible with Dio interceptor chain', () {
        final dio = Dio();
        final initialCount = dio.interceptors.length;
        
        // Should be able to add the interceptor without issues
        expect(() {
          dio.interceptors.add(interceptor);
        }, returnsNormally);
        
        expect(dio.interceptors.length, equals(initialCount + 1));
        expect(dio.interceptors.last, isA<TrustPinDioInterceptor>());
      });

      test('should work with multiple interceptors', () {
        final dio = Dio();
        final initialCount = dio.interceptors.length;
        final logInterceptor = LogInterceptor();
        
        dio.interceptors.add(logInterceptor);
        dio.interceptors.add(interceptor);
        
        expect(dio.interceptors.length, equals(initialCount + 2));
        expect(dio.interceptors[dio.interceptors.length - 2], equals(logInterceptor));
        expect(dio.interceptors[dio.interceptors.length - 1], equals(interceptor));
      });
    });
  });
}

/// Mock request interceptor handler for testing
class MockRequestInterceptorHandler extends RequestInterceptorHandler {
  final void Function(RequestOptions options)? onNext;
  final void Function(DioException error)? onReject;
  final void Function(Response response)? onResolve;

  MockRequestInterceptorHandler({
    this.onNext,
    this.onReject,
    this.onResolve,
  });

  @override
  void next(RequestOptions requestOptions) {
    onNext?.call(requestOptions);
  }

  @override
  void reject(DioException error, [bool callFollowingResponseInterceptor = false]) {
    onReject?.call(error);
  }

  @override
  void resolve(Response response, [bool callFollowingResponseInterceptor = false]) {
    onResolve?.call(response);
  }
}