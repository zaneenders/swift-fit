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
    .macOS(.v13)
  ],
  products: [
    .library(name: "SwiftFit", targets: ["SwiftFit"]),
    .library(name: "SwiftFitActivity", targets: ["SwiftFitActivity"]),
    .library(name: "SwiftFitActivityFixtures", targets: ["SwiftFitActivityFixtures"]),
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
    ),
    .target(
      name: "SwiftFitActivity",
      dependencies: ["SwiftFit"]
    ),
    .target(
      name: "SwiftFitActivityFixtures",
      resources: [
        .copy("sample.fit")
      ]
    ),
    .testTarget(
      name: "SwiftFitTests",
      dependencies: ["SwiftFit"],
    ),
    .testTarget(
      name: "SwiftFitActivityTests",
      dependencies: ["SwiftFitActivity", "SwiftFitActivityFixtures", "SwiftFit"],
    ),
  ]
)

for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(contentsOf: packageSettings)
  target.swiftSettings = settings
}
