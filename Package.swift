// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "SwiftFit",
  products: [
    .library(name: "SwiftFit", targets: ["SwiftFit"]),
    .library(name: "SwiftFitActivity", targets: ["SwiftFitActivity"]),
    .executable(name: "SwiftFitBenchmark", targets: ["SwiftFitBenchmark"]),
    .executable(name: "swift-fit-generate", targets: ["SwiftFitGenerate"]),
  ],
  targets: [
    .target(
      name: "SwiftFit",
      path: "Sources/SwiftFit",
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .enableExperimentalFeature("Lifetimes"),
        .swiftLanguageMode(.v6),
        .strictMemorySafety(),
      ]
    ),
    .executableTarget(
      name: "SwiftFitBenchmark",
      dependencies: ["SwiftFit"],
      path: "Benchmark"
    ),
    .executableTarget(
      name: "SwiftFitGenerate",
      dependencies: ["SwiftFit"],
      path: "Sources/SwiftFitGenerate",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .target(
      name: "SwiftFitActivity",
      dependencies: ["SwiftFit"],
      path: "Sources/SwiftFitActivity",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "SwiftFitTests",
      dependencies: ["SwiftFit"],
      path: "Tests/SwiftFitTests"
    ),
    .testTarget(
      name: "SwiftFitActivityTests",
      dependencies: ["SwiftFitActivity", "SwiftFit"],
      path: "Tests/SwiftFitActivityTests",
      resources: [
        .copy("Fixtures"),
      ]
    ),
  ]
)
