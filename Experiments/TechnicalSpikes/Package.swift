// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BookAtlasTechnicalSpikes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpikeCore", targets: ["SpikeCore"]),
        .library(name: "SpikeUI", targets: ["SpikeUI"]),
        .library(name: "SwiftDataCandidate", targets: ["SwiftDataCandidate"]),
        .executable(name: "SpikeBenchmark", targets: ["SpikeBenchmark"])
    ],
    targets: [
        .target(
            name: "SpikeCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "SpikeUI",
            dependencies: ["SpikeCore"]
        ),
        .target(name: "SwiftDataCandidate"),
        .executableTarget(
            name: "SpikeBenchmark",
            dependencies: ["SpikeCore"]
        ),
        .testTarget(
            name: "TechnicalSpikesTests",
            dependencies: [
                "SpikeCore",
                "SpikeUI",
                "SwiftDataCandidate"
            ]
        )
    ]
)
