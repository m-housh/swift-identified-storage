// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "swift-identified-storage",
  platforms: [
    .iOS(.v13),
    .macOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(name: "IdentifiedStorage", targets: ["IdentifiedStorage"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies.git",
      from: "1.0.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-identified-collections.git",
      from: "1.0.0"
    )
  ],
  targets: [
    .target(
      name: "IdentifiedStorage",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections")
      ]
    ),
    .testTarget(
      name: "IdentifiedStorageTests",
      dependencies: ["IdentifiedStorage"]
    ),
  ]
)
