// swift-tools-version: 6.2
import PackageDescription

// The logic Peony's app and root helper share: profiles, validation, log parsing,
// interface and reachability checks. No UI, so its tests build with any SDK.
let package = Package(
  name: "PeonyCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "PeonyCore", targets: ["PeonyCore"])],
  targets: [
    .target(name: "PeonyCore"),
    .testTarget(name: "PeonyCoreTests", dependencies: ["PeonyCore"]),
  ]
)
