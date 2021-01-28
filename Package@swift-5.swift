// swift-tools-version:5.0
import PackageDescription

let package = Package(
  name: "WebPackMiniS",
	
  products: [
    .library(name: "WebPackMiniS", targets: [ "WebPackMiniS" ])
  ],
  targets: [
    .target(name: "WebPackMiniS"),
    .testTarget(name: "WebPackMiniSTests", dependencies: [ "WebPackMiniS" ])
  ]
)
