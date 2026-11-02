import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';
import 'package:trustpin_sdk/trustpin_sdk_platform_interface.dart';

const _header = 'TrustPin-Attestation';

/// A platform whose "attestation provider" answers for [attestedHosts] with
/// `token-<host>`, as the native provider registered by trustpin_attest would.
class _AttestingPlatform extends TrustPinSDKPlatform
    with MockPlatformInterfaceMixin {
  final Set<String> attestedHosts;
  final List<String> validatedHosts = [];
  final List<_HeadersCall> headerCalls = [];
  Object? throwOnHeaders;

  _AttestingPlatform({this.attestedHosts = const {}});

  Map<String, String> _provider(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || !attestedHosts.contains(uri.host)) {
      return const {};
    }
    return {_header: 'token-${uri.host}'};
  }

  @override
  Future<void> validateConnection(
    String host, {
    int port = 443,
    int? timeoutMs,
    String? instanceId,
  }) async {
    validatedHosts.add(host);
    if (host == 'mitm.example.com') {
      throw PlatformException(code: 'PINS_MISMATCH', message: 'mismatch');
    }
  }

  @override
  Future<Map<String, String>> attestationHeaders(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? instanceId,
  }) async {
    headerCalls.add(_HeadersCall(
        'attestationHeaders', url, method, Map.of(headers), instanceId));
    final error = throwOnHeaders;
    if (error != null) throw error;
    return _provider(url);
  }

  @override
  Future<Map<String, String>> redirectedRequestHeaders(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? instanceId,
  }) async {
    headerCalls.add(_HeadersCall(
        'redirectedRequestHeaders', url, method, Map.of(headers), instanceId));
    final error = throwOnHeaders;
    if (error != null) throw error;
    return {
      for (final entry in headers.entries)
        if (entry.key.toLowerCase() != _header.toLowerCase())
          entry.key: entry.value,
      ..._provider(url),
    };
  }
}

class _HeadersCall {
  final String name;
  final String url;
  final String method;
  final Map<String, String> headers;
  final String? instanceId;

  _HeadersCall(this.name, this.url, this.method, this.headers, this.instanceId);
}

/// A Dio adapter answering from [responses], keyed by URL, and recording
/// every request it receives.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function()> responses;
  final List<RequestOptions> requests = [];

  _FakeAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final responder = responses[options.uri.toString()];
    return responder?.call() ?? ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _redirect(String location, [int status = 302]) =>
    ResponseBody.fromString('', status, headers: {
      'location': [location],
    });

ResponseBody _ok() => ResponseBody.fromString('ok', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AttestingPlatform platform;

  setUp(() {
    platform = _AttestingPlatform(
      attestedHosts: {'api.example.com', 'eu.example.com'},
    );
    TrustPinSDKPlatform.instance = platform;
  });

  group('TrustPin.attestationHeaders', () {
    test('returns the provider headers for an attested HTTPS URL', () async {
      final headers = await TrustPin.shared.attestationHeaders(
        Uri.parse('https://api.example.com/home'),
        method: 'POST',
        headers: {'Authorization': 'Bearer abc'},
      );

      expect(headers, {_header: 'token-api.example.com'});
      final call = platform.headerCalls.single;
      expect(call.method, 'POST');
      expect(call.headers, {'Authorization': 'Bearer abc'});
      expect(call.instanceId, isNull);
    });

    test('passes the named instance id', () async {
      await TrustPin.instance('com.example.lib')
          .attestationHeaders(Uri.parse('https://api.example.com/'));

      expect(platform.headerCalls.single.instanceId, 'com.example.lib');
    });

    test('leaves the HTTPS rule to the native SDK', () async {
      final headers = await TrustPin.shared
          .attestationHeaders(Uri.parse('http://api.example.com/'));

      expect(headers, isEmpty);
      expect(platform.headerCalls.single.url, 'http://api.example.com/');
    });

    test('never throws: a platform error gives no headers', () async {
      platform.throwOnHeaders =
          PlatformException(code: 'ATTESTATION_HEADERS_ERROR');

      final headers = await TrustPin.shared
          .attestationHeaders(Uri.parse('https://api.example.com/'));

      expect(headers, isEmpty);
    });
  });

  group('TrustPin.redirectedRequestHeaders', () {
    test('never throws: a platform error removes the attestation header',
        () async {
      platform.throwOnHeaders = MissingPluginException();

      final headers = await TrustPin.shared.redirectedRequestHeaders(
        Uri.parse('https://other.example.com/'),
        headers: {'trustpin-attestation': 'old', 'Accept': 'text/plain'},
      );

      expect(headers, {'Accept': 'text/plain'});
    });
  });

  group('TrustPinHttpClient with attestation', () {
    test('adds the header after pinning', () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        return http.Response('ok', 200);
      }));

      await client.get(Uri.parse('https://api.example.com/home'));

      expect(platform.validatedHosts, ['api.example.com']);
      expect(sent.single.headers[_header], 'token-api.example.com');
      expect(sent.single.followRedirects, isFalse);
    });

    test('leaves requests to other hosts unchanged', () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        return http.Response('ok', 200);
      }));

      await client.get(Uri.parse('https://cdn.example.com/a'));

      expect(sent.single.headers.containsKey(_header), isFalse);
      expect(sent.single.followRedirects, isTrue);
    });

    test('never replaces a header the app set', () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        return http.Response('ok', 200);
      }));

      await client.get(
        Uri.parse('https://api.example.com/home'),
        headers: {'trustpin-attestation': 'mine'},
      );

      expect(sent.single.headers[_header], 'mine');
    });

    test('follows a redirect: pins the new host and re-asks for its header',
        () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        if (request.url.host == 'api.example.com') {
          return http.Response('', 302,
              headers: {'location': 'https://eu.example.com/home'});
        }
        return http.Response('ok', 200);
      }));

      final response = await client.get(
        Uri.parse('https://api.example.com/home'),
        headers: {'Authorization': 'Bearer abc'},
      );

      expect(response.statusCode, 200);
      expect(platform.validatedHosts, ['api.example.com', 'eu.example.com']);
      expect(sent, hasLength(2));
      expect(sent[1].url.toString(), 'https://eu.example.com/home');
      expect(sent[1].headers[_header], 'token-eu.example.com');
      // Credentials don't cross to another host, as with dart:io.
      expect(sent[1].headers.containsKey('authorization'), isFalse);
      expect(sent[1].followRedirects, isFalse);
    });

    test('a redirect to a host that is not attested drops the header',
        () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        if (request.url.host == 'api.example.com') {
          return http.Response('', 301,
              headers: {'location': 'https://cdn.example.com/x'});
        }
        return http.Response('ok', 200);
      }));

      await client.get(Uri.parse('https://api.example.com/home'));

      expect(sent[1].headers.containsKey(_header), isFalse);
      expect(sent[1].headers.containsKey('trustpin-attestation'), isFalse);
    });

    test('a redirect hop that fails pinning throws', () async {
      final client = TrustPinHttpClient(MockClient((request) async {
        return http.Response('', 302,
            headers: {'location': 'https://mitm.example.com/'});
      }));

      expect(
        client.get(Uri.parse('https://api.example.com/home')),
        throwsA(isA<TrustPinException>()),
      );
    });

    test('stops after maxRedirects', () async {
      final client = TrustPinHttpClient(MockClient((request) async {
        return http.Response('', 302,
            headers: {'location': 'https://api.example.com/loop'});
      }));
      final request =
          http.Request('GET', Uri.parse('https://api.example.com/home'))
            ..maxRedirects = 2;

      expect(
        client.send(request),
        throwsA(isA<http.ClientException>()
            .having((e) => e.message, 'message', 'Redirect limit exceeded')),
      );
    });

    test('does not follow a redirect of a POST', () async {
      final sent = <http.BaseRequest>[];
      final client = TrustPinHttpClient(MockClient((request) async {
        sent.add(request);
        return http.Response('', 302,
            headers: {'location': 'https://eu.example.com/home'});
      }));

      final response =
          await client.post(Uri.parse('https://api.example.com/home'));

      expect(response.statusCode, 302);
      expect(sent, hasLength(1));
      expect(sent.single.followRedirects, isFalse);
    });
  });

  group('TrustPinDioInterceptor with attestation', () {
    test('adds the header after pinning', () async {
      final adapter = _FakeAdapter({'https://api.example.com/home': _ok});
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(TrustPinDioInterceptor(dio: dio));

      await dio.get<String>('https://api.example.com/home');

      expect(platform.validatedHosts, ['api.example.com']);
      expect(adapter.requests.single.headers[_header], 'token-api.example.com');
      expect(adapter.requests.single.followRedirects, isFalse);
    });

    test('leaves requests to other hosts unchanged', () async {
      final adapter = _FakeAdapter({'https://cdn.example.com/a': _ok});
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(TrustPinDioInterceptor(dio: dio));

      await dio.get<String>('https://cdn.example.com/a');

      expect(adapter.requests.single.headers.containsKey(_header), isFalse);
      expect(adapter.requests.single.followRedirects, isTrue);
    });

    test('follows a redirect with the Dio instance', () async {
      final adapter = _FakeAdapter({
        'https://api.example.com/home': () =>
            _redirect('https://eu.example.com/home?x=1'),
        'https://eu.example.com/home?x=1': _ok,
      });
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(TrustPinDioInterceptor(dio: dio));

      final response = await dio.get<String>(
        'https://api.example.com/home',
        options: Options(headers: {'Authorization': 'Bearer abc'}),
      );

      expect(response.statusCode, 200);
      expect(platform.validatedHosts, ['api.example.com', 'eu.example.com']);
      final hop = adapter.requests[1];
      expect(hop.uri.toString(), 'https://eu.example.com/home?x=1');
      expect(hop.headers[_header], 'token-eu.example.com');
      expect(hop.headers.containsKey('Authorization'), isFalse);
      // The hop's header comes from the redirect call, not a second lookup.
      expect(
        platform.headerCalls.map((c) => c.name),
        ['attestationHeaders', 'redirectedRequestHeaders'],
      );
    });

    test('without the Dio instance the redirect reaches the app', () async {
      final adapter = _FakeAdapter({
        'https://api.example.com/home': () =>
            _redirect('https://eu.example.com/home'),
      });
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(TrustPinDioInterceptor());

      await expectLater(
        dio.get<String>('https://api.example.com/home'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 302)),
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.followRedirects, isFalse);
    });

    test('stops after maxRedirects', () async {
      final adapter = _FakeAdapter({
        'https://api.example.com/loop': () =>
            _redirect('https://api.example.com/loop'),
      });
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(TrustPinDioInterceptor(dio: dio));

      await expectLater(
        dio.get<String>('https://api.example.com/loop',
            options: Options(maxRedirects: 2)),
        throwsA(isA<DioException>()
            .having((e) => e.message, 'message', 'Redirect limit exceeded')),
      );
      expect(adapter.requests, hasLength(3));
    });
  });
}
