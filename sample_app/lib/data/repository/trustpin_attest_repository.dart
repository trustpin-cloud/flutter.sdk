import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:trustpin_attest/trustpin_attest.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

import '../../domain/model/attestation_status.dart';
import '../../domain/model/domain_error.dart';
import '../../domain/repository/attestation_repository.dart';

/// Adapts [TrustPinAttest] and the sample API to the [AttestationRepository]
/// contract.
///
/// The sample API's address and demo credentials come from the Flutter asset
/// `assets/api-test.json` (copy `assets/api-test.json.example`). A debug
/// token for simulators and emulators comes from the build:
/// `flutter run --dart-define=TRUSTPIN_DEBUG_TOKEN=…`.
class TrustPinAttestRepository implements AttestationRepository {
  static const String _debugToken = String.fromEnvironment(
    'TRUSTPIN_DEBUG_TOKEN',
  );
  static const String _apiConfigAsset = 'assets/api-test.json';

  /// Every request goes through TrustPin: pinned, and with the attestation
  /// header for the attested hosts.
  final TrustPinHttpClient _client;

  bool _configured = false;
  String? _sessionToken;

  TrustPinAttestRepository({TrustPinHttpClient? client})
    : _client = client ?? TrustPinHttpClient.create();

  @override
  bool isConfigured() => _configured;

  @override
  Stream<TrustPinAttestState> get states => TrustPinAttest.shared.stateChanges;

  @override
  Stream<TrustPinAttestEvent> get events => TrustPinAttest.shared.events;

  @override
  Future<void> setUp() async {
    final attest = TrustPinAttest.shared;
    try {
      await attest.setLogLevel(TrustPinAttestLogLevel.debug);
      await attest.setupWithNativeBundle(
        debugToken: _debugToken.isEmpty ? null : _debugToken,
      );
      // Each token is bound to the request's Authorization header: a token
      // stolen from one session is useless with another.
      await attest.bindToHeader('Authorization');
      await attest.prefetch();
      _configured = true;
    } on TrustPinAttestException catch (e) {
      throw AttestationError(e.code, e.message);
    }
  }

  @override
  Future<ProtectedCallOutcome> callProtectedEndpoint() async {
    final api = await _loadApiConfig();
    return _guarded(() async {
      final session = _sessionToken ??= await _login(api);
      final response = await _client.get(
        Uri.parse('${api.baseUrl}/home'),
        headers: {'Authorization': 'Bearer $session'},
      );
      return _outcome(response);
    });
  }

  @override
  Future<ProtectedCallOutcome> callSensitiveEndpoint() async {
    final api = await _loadApiConfig();
    return _guarded(() async {
      final session = _sessionToken ??= await _login(api);
      final url = Uri.parse('${api.baseUrl}/transfer');
      final body = utf8.encode(jsonEncode({'amount': '1.00', 'to': 'demo'}));
      final headers = {
        'Authorization': 'Bearer $session',
        'Content-Type': 'application/json',
      };
      final attest = TrustPinAttest.shared;
      // The token first, so the header binding sees this request's session
      // value; then both headers for the sensitive operation: the token and
      // an assertion over the body's digest, which the sample API forwards
      // to the verifier.
      headers.addAll(
        await attest.attestationHeaders(url, method: 'POST', headers: headers),
      );
      headers.addAll(
        await attest.assertionHeaders(
          Uint8List.fromList(sha256.convert(body).bytes),
        ),
      );
      final response = await _client.post(url, headers: headers, body: body);
      return _outcome(response);
    });
  }

  Future<ProtectedCallOutcome> _guarded(
    Future<ProtectedCallOutcome> Function() call,
  ) async {
    try {
      return await call();
    } on TrustPinAttestException catch (e) {
      throw AttestationError(e.code, e.message);
    } on TrustPinException catch (e) {
      throw PinningError(e.code, e.message);
    } on SocketException catch (e) {
      throw NetworkError(e.message);
    } on HttpException catch (e) {
      throw NetworkError(e.message);
    }
  }

  ProtectedCallOutcome _outcome(http.Response response) {
    if (response.statusCode == 401) {
      // The session or the attestation was rejected: sign in again next
      // time.
      _sessionToken = null;
    }
    final sent = response.request?.headers.keys ?? const <String>[];
    return ProtectedCallOutcome(
      statusCode: response.statusCode,
      headerAttached: sent.any(
        (name) => name.toLowerCase() == TrustPinAttest.headerName.toLowerCase(),
      ),
      attestationSummary: _summary(response.statusCode, response.body),
      body: _prettyBody(response.body),
    );
  }

  @override
  void signOut() {
    _sessionToken = null;
  }

  @override
  Future<void> reset() async {
    try {
      await TrustPinAttest.shared.reset();
    } on TrustPinAttestException catch (e) {
      throw AttestationError(e.code, e.message);
    }
  }

  Future<String> _login(_ApiConfig api) async {
    final response = await _client.post(
      Uri.parse('${api.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': api.username, 'password': api.password}),
    );
    if (response.statusCode != 200) {
      throw NetworkError('Sign-in failed: HTTP ${response.statusCode}');
    }
    final token = (jsonDecode(response.body) as Map<String, dynamic>)['token'];
    if (token is! String || token.isEmpty) {
      throw const NetworkError('Sign-in answered without a token');
    }
    return token;
  }

  /// `"<platform>/<env> <result>[, bound][ [reasons]]"` from the API's echo of
  /// the verified token, or the refusal reason of a 401.
  static String? _summary(int statusCode, String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      if (statusCode == 401) {
        final reason = json['reason'] ?? json['error'];
        return reason == null ? null : 'rejected: $reason';
      }
      final attestation = json['attestation'];
      if (attestation is! Map<String, dynamic>) return null;
      final buffer = StringBuffer(
        '${attestation['platform']}/${attestation['env']} '
        '${attestation['result']}',
      );
      if (attestation['bound'] == true) buffer.write(', bound');
      final reasons = attestation['reasons'];
      if (reasons is List && reasons.isNotEmpty) {
        buffer.write(' [${reasons.join(', ')}]');
      }
      return buffer.toString();
    } on FormatException {
      return null;
    }
  }

  /// The body as shown in the card: JSON indented, anything else as is, cut
  /// at [_bodyLimit] characters.
  static String _prettyBody(String body) {
    var text = body.trim();
    try {
      text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on FormatException {
      // Not JSON: show it verbatim.
    }
    return text.length > _bodyLimit
        ? '${text.substring(0, _bodyLimit)}…'
        : text;
  }

  static const int _bodyLimit = 4000;

  Future<_ApiConfig> _loadApiConfig() async {
    final String text;
    try {
      text = await rootBundle.loadString(_apiConfigAsset);
    } catch (_) {
      throw const ValidationError(
        'Sample API not configured: copy assets/api-test.json.example to '
        'assets/api-test.json',
      );
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final baseUrl = (json['base_url'] as String? ?? '').replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (!baseUrl.startsWith('https://')) {
      throw const ValidationError('api-test.json: base_url must be https');
    }
    return _ApiConfig(
      baseUrl: baseUrl,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  void close() => _client.close();
}

class _ApiConfig {
  final String baseUrl;
  final String username;
  final String password;

  const _ApiConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
  });
}
