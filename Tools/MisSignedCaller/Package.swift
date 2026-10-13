// swift-tools-version: 6.2
import PackageDescription

// A caller the privileged helper must refuse.
//
// It speaks the helper's real interface through zhen-core's own client, at the release the
// app pins, so the only thing different from the app is who signed it. Built by
// `swift build`, which signs ad hoc; Scripts/release.sh can also sign it with the right team
// and the wrong identifier. Either way the helper's `setCodeSigningRequirement` must reject
// it. Not part of the app, not in any scheme, never shipped.
let package = Package(
  name: "MisSignedCaller",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/zhen-swift/zhen-core.git", exact: "0.7.0"),
  ],
  targets: [
    .executableTarget(
      name: "MisSignedCaller",
      dependencies: [.product(name: "ZhenPrivilege", package: "zhen-core")],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
  ]
)
