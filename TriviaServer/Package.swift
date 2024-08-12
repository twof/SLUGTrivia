// swift-tools-version: 6.0
import PackageDescription


let package = Package(
  name: "TriviaServer",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-rc.2"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.3.7"),
    .package(url: "https://github.com/vapor/postgres-nio", from: "1.0.0")
  ],
  targets: [
    .executableTarget(
      name: "Server",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
      ]
    ),
    .testTarget(
      name: "IntegrationTests",
      dependencies: [
        .target(name: "Server"),
        .product(name: "CustomDump", package: "swift-custom-dump")
      ]
    )
  ]
)
