// swift-tools-version: 6.3
import PackageDescription

let packageSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .strictMemorySafety(),
  .treatAllWarnings(as: .error),
  .treatWarning("StrictMemorySafety", as: .error),
]

let package = Package(
  name: "SwiftFit",
  platforms: [
    .macOS(.v13),
  ],
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
      path: "Sources/SwiftFitGenerate"
    ),
    .target(
      name: "SwiftFitActivity",
      dependencies: ["SwiftFit"],
      path: "Sources/SwiftFitActivity"
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

for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(contentsOf: packageSettings)
  target.swiftSettings = settings
}
