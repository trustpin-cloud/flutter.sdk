#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinKit

/// Raised when the inbound argument map is missing or malformed. The wrapping
/// `execute` helper converts this into an `INVALID_ARGUMENTS` Flutter error.
struct InvalidArgumentsError: Error {
    let message: String
}

/// Type-safe accessor over a `FlutterMethodCall`'s argument dictionary.
///
/// Created synchronously from the call so the underlying ObjC object never
/// crosses an isolation boundary into a background `Task`. Only Sendable
/// scalars are extracted before the async work starts.
struct Arguments {
    let raw: [String: Any]

    init(_ call: FlutterMethodCall) throws {
        guard let raw = call.arguments as? [String: Any] else {
            throw InvalidArgumentsError(message: "Arguments must be a map")
        }
        self.raw = raw
    }

    /// Returns the value for `key` as a String, or throws
    /// `InvalidArgumentsError` when missing or not a String. An empty string
    /// is considered present — the original handlers passed empty strings
    /// through to the underlying SDK, so we preserve that contract here.
    func requireString(_ key: String) throws -> String {
        guard let value = raw[key] as? String else {
            throw InvalidArgumentsError(message: "Missing required argument: \(key)")
        }
        return value
    }

    /// Returns nil for missing keys and for empty strings — empty is treated
    /// as "not provided" to match the previous handler behaviour.
    func optionalString(_ key: String) -> String? {
        guard let value = raw[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    func optionalInt(_ key: String) -> Int? {
        raw[key] as? Int
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

    /// Builds the `URLRequest` an attestation-header call describes: the
    /// `url`, `method` and `headers` arguments.
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

    /// Parses an optional URL argument. A missing or empty value returns nil.
    /// Malformed values throw `TrustPinErrors.invalidProjectConfig`, matching
    /// Android's `URI.create(...).toURL()` bridge behaviour.
    func optionalURL(_ key: String) throws -> URL? {
        guard let value = optionalString(key) else { return nil }
        guard
            let url = URL(string: value),
            let scheme = url.scheme,
            !scheme.isEmpty,
            url.host?.isEmpty == false
        else {
            throw TrustPinErrors.invalidProjectConfig
        }
        return url
    }

    /// Resolves an optional bundled-resource *name* to a file URL in the app's
    /// main bundle. Missing / empty returns nil; a name that does not resolve
    /// throws `invalidProjectConfig`, matching the native plist loader's
    /// behaviour for `EmbeddedConfigurationFile`.
    func optionalBundleResourceURL(_ key: String) throws -> URL? {
        guard let name = optionalString(key) else { return nil }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            throw TrustPinErrors.invalidProjectConfig
        }
        return url
    }
}

// MARK: - Domain value parsing

extension TrustPinMode {
    /// Maps the Dart-side string to a Swift SDK mode. Unknown / nil values
    /// fall back to `.strict`, matching the existing contract.
    init(_ raw: String?) {
        switch raw?.lowercased() {
        case "permissive": self = .permissive
        default:           self = .strict
        }
    }
}

extension TrustPinLogLevel {
    /// Maps the Dart-side string to a Swift SDK log level. Unknown / nil
    /// values fall back to `.error`, matching the existing contract.
    init(_ raw: String?) {
        switch raw?.lowercased() {
        case "none":  self = .none
        case "info":  self = .info
        case "debug": self = .debug
        default:      self = .error
        }
    }
}
