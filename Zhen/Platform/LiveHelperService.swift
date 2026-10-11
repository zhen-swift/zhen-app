import ServiceManagement

/// The helper through `SMAppService`, as a launch daemon.
///
/// The plist ships in `Contents/Library/LaunchDaemons/` with `AssociatedBundleIdentifiers`,
/// which is what makes Login Items show "Zhen" with the app's icon instead of a bare
/// reverse-DNS label. `HelperPlistTests` reads the built app's copy and pins that key.
struct LiveHelperService: HelperService {
  static let plistName = "com.jctec.zhen.helper.plist"
  private let service = SMAppService.daemon(plistName: plistName)

  var state: HelperState {
    switch service.status {
    case .notRegistered: .notInstalled
    case .requiresApproval: .requiresApproval
    case .enabled: .installed
    case .notFound: .unavailable(String(localized: "The helper is missing from this copy of Zhen."))
    @unknown default: .unavailable(String(localized: "macOS reported a state this version does not know."))
    }
  }

  func install() throws { try service.register() }
  func uninstall() async throws { try await service.unregister() }
  func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
