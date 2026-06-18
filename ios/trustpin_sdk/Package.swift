// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "trustpin_sdk",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "trustpin-sdk", targets: ["trustpin_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/trustpin-cloud/swift.sdk", exact: "6.0.0")
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
