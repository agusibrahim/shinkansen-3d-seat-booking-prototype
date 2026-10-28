// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "interactive_3d",
  platforms: [
    .iOS("12.0")
  ],
  products: [
    .library(name: "interactive-3d", targets: ["interactive_3d"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "interactive_3d",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
