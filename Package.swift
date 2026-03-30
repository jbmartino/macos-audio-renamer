// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSAudioRenamer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacOSAudioRenamer",
            path: "Sources"
        ),
        .testTarget(
            name: "MacOSAudioRenamerTests",
            dependencies: ["MacOSAudioRenamer"],
            path: "Tests"
        )
    ]
)
