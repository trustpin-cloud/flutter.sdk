import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  group('TrustPinConfiguration.fromAssets', () {
    test('parses all fields from a fully populated asset', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'mode': 'permissive',
          'configuration_url': 'https://custom.example.com/config/signed.b64',
          'unknown_future_field': 'ignored',
        }),
      });

      final config = await TrustPinConfiguration.fromAssets(bundle: bundle);

      expect(config.organizationId, 'org-1');
      expect(config.projectId, 'proj-1');
      expect(config.publicKey, 'cHVibGljLWtleQ==');
      expect(config.mode, TrustPinMode.permissive);
      expect(
        config.configurationURL,
        Uri.parse('https://custom.example.com/config/signed.b64'),
      );
    });

    test('defaults mode to strict and configurationURL to null when omitted',
        () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
        }),
      });

      final config = await TrustPinConfiguration.fromAssets(bundle: bundle);

      expect(config.mode, TrustPinMode.strict);
      expect(config.configurationURL, isNull);
    });

    test('treats empty configuration_url as unset', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'configuration_url': '',
        }),
      });

      final config = await TrustPinConfiguration.fromAssets(bundle: bundle);

      expect(config.configurationURL, isNull);
    });

    test('reads from a custom asset path', () async {
      final bundle = _FakeAssetBundle({
        'config/trustpin-prod.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
        }),
      });

      final config = await TrustPinConfiguration.fromAssets(
        assetPath: 'config/trustpin-prod.json',
        bundle: bundle,
      );

      expect(config.organizationId, 'org-1');
    });

    test('throws INVALID_PROJECT_CONFIG when the asset is missing', () async {
      final bundle = _FakeAssetBundle(const {});

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(
          isA<TrustPinException>()
              .having((e) => e.code, 'code', 'INVALID_PROJECT_CONFIG'),
        ),
      );
    });

    test('throws INVALID_PROJECT_CONFIG on malformed JSON', () async {
      final bundle = _FakeAssetBundle({'trustpin.json': '{not json'});

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(
          isA<TrustPinException>().having((e) => e.isInvalidProjectConfig,
              'isInvalidProjectConfig', isTrue),
        ),
      );
    });

    test('throws when the top-level JSON is not an object', () async {
      final bundle = _FakeAssetBundle({'trustpin.json': '[]'});

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>()
            .having((e) => e.code, 'code', 'INVALID_PROJECT_CONFIG')),
      );
    });

    test('throws when a required field is missing', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('organization_id'),
        )),
      );
    });

    test('throws when a required field is empty', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': '',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('organization_id'),
        )),
      );
    });

    test('throws when a required field is of the wrong type', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 42,
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('organization_id'),
        )),
      );
    });

    test('throws when mode is not strict or permissive', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'mode': 'lenient',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('mode'),
        )),
      );
    });

    test('throws when configuration_url is not a string', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'configuration_url': 12345,
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('configuration_url'),
        )),
      );
    });

    test('throws when configuration_url uses a non-https scheme', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'configuration_url': 'http://custom.example.com/config/signed.b64',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('https'),
        )),
      );
    });

    test('throws when configuration_url is a relative path', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'configuration_url': '/config/signed.b64',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('configuration_url'),
        )),
      );
    });

    test('throws when configuration_url has no host', () async {
      final bundle = _FakeAssetBundle({
        'trustpin.json': jsonEncode({
          'organization_id': 'org-1',
          'project_id': 'proj-1',
          'public_key': 'cHVibGljLWtleQ==',
          'configuration_url': 'https:///config/signed.b64',
        }),
      });

      await expectLater(
        () => TrustPinConfiguration.fromAssets(bundle: bundle),
        throwsA(isA<TrustPinException>().having(
          (e) => e.message,
          'message',
          contains('host'),
        )),
      );
    });
  });
}
