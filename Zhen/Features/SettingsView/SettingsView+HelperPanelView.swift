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
    /// The running helper's own answer, when installed: the claim, checked.
    @State private var answered: String?

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.medium) {
        Text(.usePrivilegedEngine).font(.headline).foregroundStyle(.textPrimary)
        Text(.osFingerprintingFastSynPortScans)
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(.helperCanAndCannot)
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
          Text(.allowZhenUnderSystemSettingsGeneral)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
        }
        HStack(spacing: .spacing.small) {
          switch state {
          case .notInstalled, .unavailable:
            PrimaryButton(.installHelper, systemImage: "lock.shield", identifier: "installHelperButton", action: install)
            Button(String(localized: .remove)) { confirmingRemoval = true }
              .disabled(true)
              .help(String(localized: .nothingInstalled))
              .accessibilityIdentifier("removeHelperButton")
          case .requiresApproval:
            PrimaryButton(.openLoginItems, systemImage: "gearshape", identifier: "openLoginItemsButton", action: openLoginItems)
            Button(String(localized: .remove)) { confirmingRemoval = true }
              .accessibilityIdentifier("removeHelperButton")
          case .installed:
            Button(String(localized: .showSystemSettings), action: openLoginItems)
              .accessibilityIdentifier("showInSystemSettingsButton")
            Button(String(localized: .remove)) { confirmingRemoval = true }
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
      // Approval happens in System Settings, outside this app: read the state again when
      // the person comes back. It used to stay "waiting for your approval" until Settings
      // was closed and reopened.
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        state = model.helper.state
      }
      .task(id: state) { answered = state == .installed ? await model.helper.version() : nil }
      .confirmationDialog(String(localized: .removePrivilegedEngine), isPresented: $confirmingRemoval) {
        Button(String(localized: .remove), role: .destructive, action: remove)
          .accessibilityIdentifier("confirmRemoveHelperButton")
      } message: {
        Text(.scansKeepWorkingWithoutTheyLose)
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
      case .notInstalled: String(localized: .notInstalled)
      case .requiresApproval: String(localized: .installedWaitingYourApproval)
      case .installed:
        answered.map { String(localized: .installedZhenScanEngine($0)) }
          ?? String(localized: .installedZhenScanEngineNotAnswering)
      case .unavailable(let reason): reason
      }
    }

    private func install() {
      do {
        try model.helper.install()
        failure = nil
      } catch {
        failure = String(localized: .macosDidNotRegisterHelper(error.localizedDescription))
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
          failure = String(localized: .macosDidNotRemoveHelper(error.localizedDescription))
        }
        state = model.helper.state
      }
    }
  }
}
