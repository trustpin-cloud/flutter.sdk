import '../model/connection_outcome.dart';

/// Boundary for executing TrustPin-pinned HTTPS requests. Implementations
/// build the request through `TrustPinHttpClient` and cap the body preview
/// inside the data layer so the use case logs whatever it receives.
abstract interface class NetworkRepository {
  Future<ConnectionOutcome> get(String url);
}
