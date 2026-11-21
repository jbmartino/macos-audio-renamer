// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSAudioRenamer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacOSAudioRenamer",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            // The build scripts put Sparkle.framework in the app's Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "MacOSAudioRenamerTests",
            dependencies: ["MacOSAudioRenamer"],
            path: "Tests",
            // Standalone script (`swift Tests/run_tests.swift`), not part of the test bundle.
            exclude: ["run_tests.swift"]
        )
    ]
)
