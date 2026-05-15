package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPinError
import java.io.ByteArrayInputStream
import java.security.cert.CertificateException
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.Base64

/**
 * Parses a PEM-encoded X.509 certificate string into an [X509Certificate].
 * Any parse failure (malformed PEM, bad Base64, wrong cert type) surfaces as
 * `TrustPinError.InvalidServerCert` so it maps to a stable Flutter error code.
 */
internal fun parsePemCertificate(pem: String): X509Certificate {
    val factory = CertificateFactory.getInstance("X.509")
    val cleaned = pem
        .replace("-----BEGIN CERTIFICATE-----", "")
        .replace("-----END CERTIFICATE-----", "")
        .replace("\\s".toRegex(), "")

    return try {
        val decoded = Base64.getDecoder().decode(cleaned)
        ByteArrayInputStream(decoded).use { stream ->
            factory.generateCertificate(stream) as X509Certificate
        }
    } catch (_: CertificateException) {
        throw TrustPinError.InvalidServerCert
    } catch (_: IllegalArgumentException) {
        throw TrustPinError.InvalidServerCert
    } catch (_: ClassCastException) {
        throw TrustPinError.InvalidServerCert
    }
}
