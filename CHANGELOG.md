# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-08-03

### Changed

- Improved CI/CD

## [3.3.0] - 2026-02-27

### Changed

- Updated SDKs to v3.3.0

## [3.0.1] - 2026-02-23

### Changed

- Added Swift Package Manager support for iOS and macOS
- Updated documentation

## [3.0.0] - 2026-02-19

### Added

- `fetchCertificate()` for OS-level TLS leaf certificate extraction
- `TrustPinConfiguration` class for SDK initialization
- `configurationURL` parameter for self-hosted configurations
- `TrustPinDioInterceptor` for Dio integration
- `TrustPinHttpClient` for http package integration
- `TrustPin.shared` and `TrustPin.instance('id')` for named instances

### Changed

- Renamed `TrustPinSDK` class to `TrustPin` with instance-based API
- Updated native SDKs

## [2.1.0] - 2026-02-09

### Changed

- Updated native SDKs
- Improved documentation

## [2.0.0] - 2026-01-26

### Added

- SPKI and AWS Certificate Manager support

### Changed

- Updated native SDKs

## [1.3.0] - 2026-01-23

### Changed

- Updated native SDKs

## [1.2.0] - 2025-08-14

### Changed

- Updated native SDKs

## [1.0.0] - 2025-08-05

### Added

- Initial release of TrustPin Flutter SDK
- SSL certificate pinning with SHA-256/SHA-512 public key pins
- Support for strict and permissive pinning modes
- Configurable logging levels
- iOS, Android, and macOS platform support
