// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]
let core: Target.Dependency = .product(name: "PeonyCore", package: "core")

// Build with `bun run build` (or SDKROOT="$(scripts/sdk.sh)"): Command Line Tools may ship an SDK
// whose SwiftUI macros need Xcode. Core tests live in packages/core (`bun run test`).
let package = Package(
  name: "Peony",
  platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../../packages/core")],
  targets: [
    // Every view, driven by plain values, so it renders the same in the app and in snapshots.
    .target(name: "PeonyUI", dependencies: [core], swiftSettings: mainActorByDefault),
    // The app: profiles, the connection, and the menu bar scene.
    .executableTarget(name: "Peony", dependencies: [core, "PeonyUI"], swiftSettings: mainActorByDefault),
    // The root helper. Foundation only; validates everything through PeonyCore.
    .executableTarget(name: "peony-helper", dependencies: [core]),
    // `peony`, the command-line tool for scripts and agents. PeonyCore only: it asks the app, never
    // the tunnel. Named so its product can't collide with `Peony` on a case-insensitive disk.
    .executableTarget(name: "peony-cli", dependencies: [core]),
    // `bun run snapshots` renders every panel state to PNG for design review.
    .executableTarget(name: "peony-snapshots", dependencies: [core, "PeonyUI"], swiftSettings: mainActorByDefault),
  ]
)
