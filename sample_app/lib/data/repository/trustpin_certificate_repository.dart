import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

import '../../domain/model/domain_error.dart';
import '../../domain/repository/certificate_repository.dart';

/// Fetches certificates through [TrustPin]; works without pinning set up.
class TrustPinCertificateRepository implements CertificateRepository {
  @override
  Future<CertificateInfo> fetch(String host, int port) async {
    try {
      // A diagnostic flow that needs the PEM itself: the one remaining use of
      // fetchCertificate. Pinned requests use validateConnection.
      // ignore: deprecated_member_use
      final pem = await TrustPin.shared.fetchCertificate(host, port: port);
      final body = pem
          .replaceAll(RegExp(r'-----(BEGIN|END) CERTIFICATE-----'), '')
          .replaceAll(RegExp(r'\s'), '');
      final digest = sha256.convert(base64.decode(body));
      final hex = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
      return CertificateInfo(pem: pem, sha256Fingerprint: hex);
    } on TrustPinException catch (e) {
      throw PinningError(e.code, e.message);
    } on FormatException catch (e) {
      throw UnknownError('Unreadable certificate: ${e.message}');
    }
  }
}
