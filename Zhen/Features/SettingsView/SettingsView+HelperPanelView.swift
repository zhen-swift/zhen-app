import SwiftUI

extension SettingsView {
  /// The privileged engine: what it is, what it can and cannot do, and the controls to
  /// install it, remove it, and check both claims against the OS.
  ///
  /// The copy is A3's, specified rather than left to the implementer: this is the one place
  /// in the app where the writing matters more than the layout. Remove is always beside
  /// Install — an installer with no uninstaller is how software earns distrust.
  struct HelperPanelView: View {
    @Environment(NetworkModel.self) private var model
    @State private var state: HelperState = .notInstalled
    @State private var failure: String?
    @State private var confirmingRemoval = false

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.medium) {
        Text("Use the privileged engine").font(.headline).foregroundStyle(.textPrimary)
        Text("OS fingerprinting and fast SYN port scans need raw network sockets, which macOS only grants to root. The engine is a small helper that runs only during scans and only sends results back to this app. Everything else works without it.")
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("It can: sweep this network at layer 2 (ARP), and SYN-scan ports on the devices found. It cannot: read files, run commands, or talk to anything but this app.")
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: .spacing.small) {
          StatusDot(tone)
          Text(stateLine)
            .font(.body.bold())
            .foregroundStyle(.textPrimary)
            .accessibilityIdentifier("helperState")
        }
        if state == .requiresApproval {
          Text("Allow “Zhen” under System Settings › General › Login Items to finish.")
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
        }
        HStack(spacing: .spacing.small) {
          switch state {
          case .notInstalled, .unavailable:
            PrimaryButton("Install Helper…", systemImage: "lock.shield", identifier: "installHelperButton", action: install)
            Button("Remove") { confirmingRemoval = true }
              .disabled(true)
              .help("Nothing is installed")
              .accessibilityIdentifier("removeHelperButton")
          case .requiresApproval:
            PrimaryButton("Open Login Items…", systemImage: "gearshape", identifier: "openLoginItemsButton", action: openLoginItems)
            Button("Remove") { confirmingRemoval = true }
              .accessibilityIdentifier("removeHelperButton")
          case .installed:
            Button("Show in System Settings…", action: openLoginItems)
              .accessibilityIdentifier("showInSystemSettingsButton")
            Button("Remove") { confirmingRemoval = true }
              .accessibilityIdentifier("removeHelperButton")
          }
        }
        if let failure {
          Text(failure)
            .font(.subheadline)
            .foregroundStyle(.statusWarningText)
            .accessibilityIdentifier("helperFailure")
        }
      }
      .padding(.vertical, .spacing.xSmall)
      .onAppear { state = model.helper.state }
      .confirmationDialog("Remove the privileged engine?", isPresented: $confirmingRemoval) {
        Button("Remove", role: .destructive, action: remove)
          .accessibilityIdentifier("confirmRemoveHelperButton")
      } message: {
        Text("Scans keep working without it; they lose the layer-2 sweep and SYN scanning.")
      }
    }

    private var tone: StatusDot.Tone {
      switch state {
      case .installed: .online
      case .requiresApproval: .warning
      case .notInstalled, .unavailable: .offline
      }
    }

    private var stateLine: String {
      switch state {
      case .notInstalled: String(localized: "Not installed.")
      case .requiresApproval: String(localized: "Installed · waiting for your approval")
      case .installed: String(localized: "Installed · Zhen Scan Engine")
      case .unavailable(let reason): reason
      }
    }

    private func install() {
      do {
        try model.helper.install()
        failure = nil
      } catch {
        failure = String(localized: "macOS did not register the helper: \(error.localizedDescription)")
      }
      state = model.helper.state
    }

    private func openLoginItems() {
      model.helper.openLoginItems()
      state = model.helper.state
    }

    private func remove() {
      Task {
        do {
          try await model.helper.uninstall()
          failure = nil
        } catch {
          failure = String(localized: "macOS did not remove the helper: \(error.localizedDescription)")
        }
        state = model.helper.state
      }
    }
  }
}
