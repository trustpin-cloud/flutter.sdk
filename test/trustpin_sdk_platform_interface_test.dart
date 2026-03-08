import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/trustpin_sdk_platform_interface.dart';
import 'package:trustpin_sdk/trustpin_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTrustPinSDKPlatform extends TrustPinSDKPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
  }) => Future.value();

  @override
  Future<void> verify(String domain, String certificate,
      {String? instanceId}) => Future.value();

  @override
  Future<void> setLogLevel(String logLevel, {String? instanceId}) =>
      Future.value();

  @override
  Future<String> fetchCertificate(String host,
      {int port = 443, String? instanceId}) =>
      Future.value('mock-certificate');
}

class TestTrustPinSDKPlatform extends TrustPinSDKPlatform {
  @override
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
  }) => Future.value();

  @override
  Future<void> verify(String domain, String certificate,
      {String? instanceId}) => Future.value();

  @override
  Future<void> setLogLevel(String logLevel, {String? instanceId}) =>
      Future.value();

  @override
  Future<String> fetchCertificate(String host,
      {int port = 443, String? instanceId}) =>
      Future.value('mock-certificate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustPinSDKPlatform', () {
    group('Default Instance', () {
      test('should use MethodChannelTrustPinSDK as default instance', () {
        expect(
          TrustPinSDKPlatform.instance,
          isInstanceOf<MethodChannelTrustPinSDK>(),
        );
      });

      test('should allow setting custom platform instance', () {
        final mockPlatform = MockTrustPinSDKPlatform();
        TrustPinSDKPlatform.instance = mockPlatform;

        expect(TrustPinSDKPlatform.instance, equals(mockPlatform));
        expect(
          TrustPinSDKPlatform.instance,
          isInstanceOf<MockTrustPinSDKPlatform>(),
        );
      });

      test('should maintain platform instance across multiple accesses', () {
        final mockPlatform = MockTrustPinSDKPlatform();
        TrustPinSDKPlatform.instance = mockPlatform;

        final instance1 = TrustPinSDKPlatform.instance;
        final instance2 = TrustPinSDKPlatform.instance;

        expect(instance1, equals(instance2));
        expect(instance1, equals(mockPlatform));
      });
    });

    group('Interface Compliance', () {
      test('should allow MockPlatformInterfaceMixin implementations', () {
        expect(() {
          TrustPinSDKPlatform.instance = MockTrustPinSDKPlatform();
        }, returnsNormally);
      });
    });

    group('Abstract Method Declarations', () {
      late MockTrustPinSDKPlatform mockPlatform;

      setUp(() {
        mockPlatform = MockTrustPinSDKPlatform();
        TrustPinSDKPlatform.instance = mockPlatform;
      });

      test('should declare setup method with required parameters', () async {
        expect(mockPlatform.setup, isA<Function>());

        // Should accept required parameters
        expect(() async {
          await mockPlatform.setup('org', 'project', 'key');
        }, returnsNormally);

        // Should accept optional mode parameter
        expect(() async {
          await mockPlatform.setup('org', 'project', 'key', mode: 'permissive');
        }, returnsNormally);
      });

      test('should declare verify method with required parameters', () async {
        expect(mockPlatform.verify, isA<Function>());

        expect(() async {
          await mockPlatform.verify('domain.com', 'certificate');
        }, returnsNormally);
      });

      test(
        'should declare setLogLevel method with required parameter',
        () async {
          expect(mockPlatform.setLogLevel, isA<Function>());

          expect(() async {
            await mockPlatform.setLogLevel('debug');
          }, returnsNormally);
        },
      );
    });

    group('Method Signatures', () {
      late MockTrustPinSDKPlatform mockPlatform;

      setUp(() {
        mockPlatform = MockTrustPinSDKPlatform();
        TrustPinSDKPlatform.instance = mockPlatform;
      });

      test('setup should return Future<void>', () {
        final result = mockPlatform.setup('org', 'project', 'key');
        expect(result, isA<Future<void>>());
      });

      test('verify should return Future<void>', () {
        final result = mockPlatform.verify('domain.com', 'certificate');
        expect(result, isA<Future<void>>());
      });

      test('setLogLevel should return Future<void>', () {
        final result = mockPlatform.setLogLevel('debug');
        expect(result, isA<Future<void>>());
      });
    });

    group('Default Implementation Behavior', () {
      test('should throw UnimplementedError for unimplemented methods', () {
        final platform = _UnimplementedTrustPinSDKPlatform();

        expect(() async {
          await platform.setup('org', 'project', 'key');
        }, throwsA(isA<UnimplementedError>()));

        expect(() async {
          await platform.verify('domain.com', 'certificate');
        }, throwsA(isA<UnimplementedError>()));

        expect(() async {
          await platform.setLogLevel('debug');
        }, throwsA(isA<UnimplementedError>()));
      });

      test(
        'should provide meaningful error messages for unimplemented methods',
        () async {
          final platform = _UnimplementedTrustPinSDKPlatform();

          try {
            await platform.setup('org', 'project', 'key');
            fail('Expected UnimplementedError');
          } on UnimplementedError catch (e) {
            expect(e.message, contains('setup() has not been implemented'));
          }

          try {
            await platform.verify('domain.com', 'certificate');
            fail('Expected UnimplementedError');
          } on UnimplementedError catch (e) {
            expect(e.message, contains('verify() has not been implemented'));
          }

          try {
            await platform.setLogLevel('debug');
            fail('Expected UnimplementedError');
          } on UnimplementedError catch (e) {
            expect(
              e.message,
              contains('setLogLevel() has not been implemented'),
            );
          }
        },
      );
    });

    group('Platform Interface Inheritance', () {
      test('should extend PlatformInterface', () {
        final mockPlatform = MockTrustPinSDKPlatform();
        expect(mockPlatform, isA<PlatformInterface>());
      });

      test('should have proper token for platform interface', () {
        final platform1 = MockTrustPinSDKPlatform();
        final platform2 = MockTrustPinSDKPlatform();

        // Both instances should be valid for the platform interface
        expect(() {
          TrustPinSDKPlatform.instance = platform1;
        }, returnsNormally);

        expect(() {
          TrustPinSDKPlatform.instance = platform2;
        }, returnsNormally);
      });
    });

    group('Multiple Platform Implementations', () {
      test(
        'should support switching between different platform implementations',
        () {
          final mock1 = MockTrustPinSDKPlatform();
          final mock2 = MockTrustPinSDKPlatform();

          // Set first implementation
          TrustPinSDKPlatform.instance = mock1;
          expect(TrustPinSDKPlatform.instance, equals(mock1));

          // Switch to second implementation
          TrustPinSDKPlatform.instance = mock2;
          expect(TrustPinSDKPlatform.instance, equals(mock2));
          expect(TrustPinSDKPlatform.instance, isNot(equals(mock1)));
        },
      );

      test('should maintain instance integrity across multiple calls', () {
        final mockPlatform = MockTrustPinSDKPlatform();
        TrustPinSDKPlatform.instance = mockPlatform;

        // Multiple accesses should return the same instance
        final instances = List.generate(
          10,
          (_) => TrustPinSDKPlatform.instance,
        );

        for (final instance in instances) {
          expect(instance, equals(mockPlatform));
        }
      });
    });

    group('Type Safety', () {
      test('should enforce correct parameter types', () {
        final mockPlatform = MockTrustPinSDKPlatform();

        // These should compile and run without type errors
        expect(() async {
          await mockPlatform.setup(
            'string',
            'string',
            'string',
            mode: 'string',
          );
        }, returnsNormally);

        expect(() async {
          await mockPlatform.verify('string', 'string');
        }, returnsNormally);

        expect(() async {
          await mockPlatform.setLogLevel('string');
        }, returnsNormally);
      });

      test('should return correct return types', () async {
        final mockPlatform = MockTrustPinSDKPlatform();

        final setupResult = mockPlatform.setup('org', 'project', 'key');
        expect(setupResult, isA<Future<void>>());

        final verifyResult = mockPlatform.verify('domain.com', 'cert');
        expect(verifyResult, isA<Future<void>>());

        final logLevelResult = mockPlatform.setLogLevel('debug');
        expect(logLevelResult, isA<Future<void>>());
      });
    });
  });
}

// Helper class for testing unimplemented methods
class _UnimplementedTrustPinSDKPlatform extends TrustPinSDKPlatform
    with MockPlatformInterfaceMixin {
  // Inherits default implementations that throw UnimplementedError
}
