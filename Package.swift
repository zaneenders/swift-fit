// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "SwiftFit",
  products: [
    .library(name: "SwiftFit", targets: ["SwiftFit"])
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
    .testTarget(
      name: "SwiftFitTests",
      dependencies: ["SwiftFit"],
      path: "Tests/SwiftFitTests"
    ),
  ]
)
