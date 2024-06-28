// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TriviaCore",
    platforms: [
      .iOS(.v17),
      .macOS(.v14)
    ],
    products: [
        .library(
            name: "TriviaCore",
            targets: ["TriviaCore"]
        ),
    ],
    dependencies: [
      .package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        from: "1.10.0"
      ),
      .package(url: "https://github.com/twof/FunctionSpy", branch: "main"),
//      .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "TriviaCore",
            dependencies: [
              .product(
                name: "ComposableArchitecture",
                package: "swift-composable-architecture"
              ),
            ]
        ),
        .testTarget(
            name: "TriviaCoreTests",
            dependencies: [
              "TriviaCore",
              "FunctionSpy"
            ]
        ),
    ],
    swiftLanguageVersions: [.v6]
)
