// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "trustpin_sdk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "trustpin-sdk", targets: ["trustpin_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/trustpin-cloud/swift.sdk", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "trustpin_sdk",
            dependencies: [
                .product(name: "TrustPinKit", package: "swift.sdk")
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
