// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SwiftSecretKeys",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "sskeys", targets: ["sskeys"]),
        .library(name: "SwiftSecretKeysCore", targets: ["SwiftSecretKeysCore"]),
        .plugin(name: "SwiftSecretKeysPlugin", targets: ["SwiftSecretKeysPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftSecretKeysCore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .executableTarget(
            name: "sskeys",
            dependencies: [
                "SwiftSecretKeysCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .plugin(
            name: "SwiftSecretKeysPlugin",
            capability: .buildTool(),
            dependencies: ["sskeys"]
        ),
        .testTarget(
            name: "SwiftSecretKeysCoreTests",
            dependencies: [
                "SwiftSecretKeysCore",
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
