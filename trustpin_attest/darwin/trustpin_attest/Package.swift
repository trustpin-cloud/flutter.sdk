// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "trustpin_attest",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "trustpin-attest", targets: ["trustpin_attest"])
    ],
    dependencies: [
        // Same 7.1.x line as the trustpin_sdk plugin, so both plugins share
        // one TrustPinKit and its instances.
        .package(url: "https://github.com/trustpin-cloud/swift.sdk", .upToNextMinor(from: "7.1.0"))
    ],
    targets: [
        .target(
            name: "trustpin_attest",
            dependencies: [
                .product(name: "TrustPinKit", package: "swift.sdk"),
                .product(name: "TrustPinAttestKit", package: "swift.sdk")
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
