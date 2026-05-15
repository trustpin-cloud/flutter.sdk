import 'dart:io';

import 'package:trustpin_sdk/trustpin_sdk.dart';

import '../../domain/model/connection_outcome.dart';
import '../../domain/model/domain_error.dart';
import '../../domain/repository/network_repository.dart';

/// Backed by [TrustPinHttpClient] (which routes every HTTPS request through
/// `TrustPin.validateConnection` internally). Body preview is capped at
/// [_bodyPreviewLimit] characters here — the data-layer truncation contract.
class HttpNetworkRepository implements NetworkRepository {
  static const int _bodyPreviewLimit = 200;
  static const String _userAgent = 'TrustPin-Flutter-Sample/1.0.0';

  final TrustPinHttpClient _client;

  HttpNetworkRepository({TrustPinHttpClient? client})
    : _client = client ?? TrustPinHttpClient.create();

  @override
  Future<ConnectionOutcome> get(String url) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );

      final body = response.body;
      final preview = body.length > _bodyPreviewLimit
          ? '${body.substring(0, _bodyPreviewLimit)}…'
          : body;

      return ConnectionOutcome(
        statusCode: response.statusCode,
        message: response.reasonPhrase ?? '',
        headerCount: response.headers.length,
        bodyPreview: preview,
      );
    } on TrustPinException catch (e) {
      throw PinningError(e.code, e.message);
    } on SocketException catch (e) {
      throw NetworkError(e.message);
    } on HttpException catch (e) {
      throw NetworkError(e.message);
    } on FormatException catch (e) {
      throw ValidationError('Invalid URL: ${e.message}');
    } catch (e) {
      throw UnknownError(e.toString());
    }
  }

  void close() => _client.close();
}
