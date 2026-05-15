/// Sealed error surface returned by use cases.
///
/// The data layer maps raw exceptions (TrustPinException, SocketException,
/// etc.) into one of these so the presentation layer can render outcomes
/// without depending on SDK or transport types.
sealed class DomainError implements Exception {
  final String message;

  const DomainError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Caller-supplied input failed validation before any I/O.
class ValidationError extends DomainError {
  const ValidationError(super.message);
}

/// TrustPin SDK rejected the configuration or a pin check.
class PinningError extends DomainError {
  final String code;

  const PinningError(this.code, super.message);
}

/// Transport-level failure during a network request.
class NetworkError extends DomainError {
  const NetworkError(super.message);
}

/// Anything the data layer could not classify.
class UnknownError extends DomainError {
  const UnknownError(super.message);
}
