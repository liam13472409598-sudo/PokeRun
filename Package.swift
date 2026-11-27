// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PokeRun",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokeRun",
            path: "Sources/PokeRun",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
    ]
)
