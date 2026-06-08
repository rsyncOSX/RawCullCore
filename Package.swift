// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RawCullCore",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "RawCullCore",
            targets: ["RawCullCore"],
        )
    ],
    targets: [
        .target(
            name: "RawCullCore",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ],
        ),
        .testTarget(
            name: "RawCullCoreTests",
            dependencies: ["RawCullCore"],
        )
    ],
    swiftLanguageModes: [.v6],
)
