#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinAttestKit

/// Raised when the inbound argument map is missing or malformed. The wrapping
/// `execute` helper converts this into an `INVALID_ARGUMENTS` Flutter error.
struct InvalidArgumentsError: Error {
    let message: String
}

/// Type-safe accessor over a `FlutterMethodCall`'s argument dictionary.
///
/// Created synchronously from the call so the underlying ObjC object never
/// crosses an isolation boundary into a background `Task`. Only Sendable
/// values are extracted before the async work starts.
struct Arguments {
    let raw: [String: Any]

    init(_ call: FlutterMethodCall) throws {
        guard let raw = call.arguments as? [String: Any] else {
            throw InvalidArgumentsError(message: "Arguments must be a map")
        }
        self.raw = raw
    }

    func requireString(_ key: String) throws -> String {
        guard let value = raw[key] as? String else {
            throw InvalidArgumentsError(message: "Missing required argument: \(key)")
        }
        return value
    }

    /// Returns nil for missing keys and for empty strings.
    func optionalString(_ key: String) -> String? {
        guard let value = raw[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    /// Returns nil for a missing key; an explicit empty string stays empty,
    /// so a binding can be set to "".
    func nullableString(_ key: String) -> String? {
        raw[key] as? String
    }

    func stringList(_ key: String) throws -> [String] {
        guard let values = raw[key] as? [Any] else {
            throw InvalidArgumentsError(message: "Missing required argument: \(key)")
        }
        return values.compactMap { $0 as? String }
    }

    /// A Dart `Uint8List` argument.
    func requireData(_ key: String) throws -> Data {
        guard let value = raw[key] as? FlutterStandardTypedData else {
            throw InvalidArgumentsError(message: "Missing required argument: \(key)")
        }
        return value.data
    }

    /// Returns a string-to-string map, or an empty one when the key is
    /// missing. Entries whose key or value isn't a String are dropped.
    func stringMap(_ key: String) -> [String: String] {
        guard let map = raw[key] as? [AnyHashable: Any] else { return [:] }
        var result: [String: String] = [:]
        for (name, value) in map {
            if let name = name as? String, let value = value as? String {
                result[name] = value
            }
        }
        return result
    }

    /// Builds the `URLRequest` an `attestationHeaders` call describes.
    func request() throws -> URLRequest {
        let rawURL = try requireString(Arg.url)
        guard let url = URL(string: rawURL), url.scheme != nil, url.host != nil else {
            throw InvalidArgumentsError(message: "Invalid argument: \(Arg.url)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = optionalString(Arg.method) ?? "GET"
        for (name, value) in stringMap(Arg.headers) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}

// MARK: - Domain value parsing

extension TrustPinAttestLogLevel {
    /// Maps the Dart-side string to a log level. Unknown values fall back to
    /// `.none`, logging's default.
    init(wireName: String?) {
        switch wireName?.lowercased() {
        case "error":   self = .error
        case "warning": self = .warning
        case "info":    self = .info
        case "debug":   self = .debug
        default:        self = .none
        }
    }

    /// The wire string for this level. Keep in sync with the Dart
    /// `TrustPinAttestLogLevel.value` strings.
    var wireName: String {
        switch self {
        case .none:    return "none"
        case .error:   return "error"
        case .warning: return "warning"
        case .info:    return "info"
        case .debug:   return "debug"
        @unknown default: return "info"
        }
    }
}

extension TrustPinAttestState {
    /// The map sent to Dart for this state. A retry time a year or more away
    /// (`.distantFuture`) is sent as no retry time.
    func wireMap(instanceId: String) -> [String: Any] {
        var map: [String: Any] = [EventKey.instanceId: instanceId]
        switch self {
        case .unavailable:
            map[EventKey.state] = "unavailable"
        case .attesting:
            map[EventKey.state] = "attesting"
        case .ready(let expiresAt):
            map[EventKey.state] = "ready"
            map[EventKey.expiresAtMs] = milliseconds(expiresAt)
        case .failed(let error, let retryAt):
            map[EventKey.state] = "failed"
            map[EventKey.code] = mapAttestError(error)
            map[EventKey.message] = error.localizedDescription
            map[EventKey.reasons] = reasons(of: error)
            map[EventKey.retryAtMs] = retryTime(retryAt)
        @unknown default:
            map[EventKey.state] = "unavailable"
        }
        return map
    }
}

extension TrustPinAttestEvent {
    /// The map sent to Dart for this event: its name and its own fields,
    /// nothing else. Durations and times are milliseconds.
    func wireMap(instanceId: String) -> [String: Any] {
        var map: [String: Any] = [EventKey.instanceId: instanceId]
        switch self {
        case .keyGenerated:
            map[EventKey.event] = "keyGenerated"
        case .keyReplaced(let count):
            map[EventKey.event] = "keyReplaced"
            map[EventKey.count] = count
        case .attestationSucceeded(let duration):
            map[EventKey.event] = "attestationSucceeded"
            map[EventKey.durationMs] = milliseconds(duration)
        case .refused(let retryAt):
            map[EventKey.event] = "refused"
            map[EventKey.retryAtMs] = retryTime(retryAt)
        case .attestationFailed(let reasons, let retryAt):
            map[EventKey.event] = "attestationFailed"
            map[EventKey.reasons] = reasons
            map[EventKey.retryAtMs] = retryTime(retryAt)
        case .refreshSucceeded(let duration):
            map[EventKey.event] = "refreshSucceeded"
            map[EventKey.durationMs] = milliseconds(duration)
        case .refreshFailed(let error):
            map.merge(error.wireFields(event: "refreshFailed")) { $1 }
        case .waitEntered(let until):
            map[EventKey.event] = "waitEntered"
            map[EventKey.untilMs] = milliseconds(until)
        case .waitCleared:
            map[EventKey.event] = "waitCleared"
        case .deviceUnsupported:
            map[EventKey.event] = "deviceUnsupported"
        case .verifierUnavailable:
            map[EventKey.event] = "verifierUnavailable"
        case .assertionSucceeded(let duration):
            map[EventKey.event] = "assertionSucceeded"
            map[EventKey.durationMs] = milliseconds(duration)
        case .assertionFailed(let error):
            map.merge(error.wireFields(event: "assertionFailed")) { $1 }
        @unknown default:
            // A newer native event: Dart ignores names it doesn't know.
            map[EventKey.event] = "unknown"
        }
        return map
    }
}

private extension TrustPinAttestError {
    func wireFields(event: String) -> [String: Any] {
        [
            EventKey.event: event,
            EventKey.code: mapAttestError(self),
            EventKey.message: localizedDescription,
            EventKey.reasons: reasons(of: self),
        ]
    }
}

/// A retry time a year or more away (`.distantFuture`) is sent as no retry
/// time, `NSNull`, so Dart sees the key with a null value.
private func retryTime(_ date: Date) -> Any {
    date.timeIntervalSinceNow < 365 * 24 * 3600 ? milliseconds(date) : NSNull()
}

private func milliseconds(_ interval: TimeInterval) -> Int {
    Int((interval * 1000).rounded())
}

private func milliseconds(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1000).rounded())
}
