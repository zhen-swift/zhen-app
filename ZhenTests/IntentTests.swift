import Foundation
import Testing

@testable import Zhen

/// Phase 3, part 2: the App Intents do what the toolbar does, on the same model.
@MainActor
struct IntentTests {
  /// Gate. Break: drop `model.startScan()` from `ScanNetworkIntent.run`.
  @Test("Scan Network starts the scan the toolbar would, and says so")
  func scanNetwork() async {
    let model = await ScanningBehaviourTests.loadedModel()
    #expect(ScanNetworkIntent.run(on: model) == "Scanning your network.")
    #expect(model.scan.isRunning)
    #expect(ScanNetworkIntent.run(on: model) == "Zhen is already scanning.", "a second scan was asked for while one ran")
  }

  @Test("Count Online Devices reads history, loading it first when the app has just launched")
  func onlineDevices() async {
    let environment = AppEnvironment.parse(arguments: ["-Fixture", "home", "-UITesting"], environment: [:], now: .now)
    let model = NetworkModel(environment: environment)
    #expect(!model.hasLoaded)
    let count = await OnlineDevicesIntent.run(on: model)
    #expect(model.hasLoaded)
    #expect(count == model.onlineCount)
    #expect(count > 0)
  }
}
