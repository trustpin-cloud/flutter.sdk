/// Comprehensive test runner for TrustPin Flutter SDK
/// 
/// This file imports and runs all test suites to ensure complete coverage
/// Run with: flutter test test/all_tests.dart
library;

import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'http_interceptors/dio_interceptor_test.dart' as dio_interceptor_tests;
import 'http_interceptors/http_client_interceptor_test.dart' as http_client_interceptor_tests;
import 'trustpin_sdk_method_channel_test.dart' as method_channel_tests;
import 'trustpin_sdk_platform_interface_test.dart' as platform_interface_tests;

void main() {
  group('TrustPin Flutter SDK - Complete Test Suite', () {
    group('HTTP Interceptors Tests', () {
      group('Dio Interceptor', () {
        dio_interceptor_tests.main();
      });

      group('HTTP Client Interceptor', () {
        http_client_interceptor_tests.main();
      });
    });

    group('Method Channel Tests', () {
      method_channel_tests.main();
    });

    group('Platform Interface Tests', () {
      platform_interface_tests.main();
    });
  });
}