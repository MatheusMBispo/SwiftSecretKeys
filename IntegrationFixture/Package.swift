// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "IntegrationFixture",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../"),
    ],
    targets: [
        .executableTarget(
            name: "FixtureApp",
            plugins: [
                .plugin(name: "SwiftSecretKeysPlugin", package: "SwiftSecretKeys")
            ]
        ),
    ]
)
