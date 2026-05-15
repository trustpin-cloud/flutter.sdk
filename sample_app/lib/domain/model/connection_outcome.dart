/// Result of a TrustPin-pinned HTTPS request, as surfaced to the use-case
/// layer. The body has already been truncated by the data layer so the use
/// case logs whatever it gets without re-truncating.
class ConnectionOutcome {
  final int statusCode;
  final String message;
  final int headerCount;
  final String bodyPreview;

  const ConnectionOutcome({
    required this.statusCode,
    required this.message,
    required this.headerCount,
    required this.bodyPreview,
  });
}
