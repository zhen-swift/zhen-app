import SwiftUI
import ZhenCore

extension RootView {
  /// Gives a device a name of its own. Local only: there is no controller to write back
  /// to, so the name is kept by this app and shown in "Known by" as source "You".
  struct RenameSheet: View {
    let id: DeviceItem.ID
    @Environment(NetworkModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
      let device = model.device(id)
      Form {
        TextField(String(localized: .name), text: $name, prompt: Text(device?.device.displayName ?? String(localized: .unidentifiedDevice)))
          .focused($fieldFocused)
          .onSubmit(confirm)
          .accessibilityIdentifier("renameField")
        Text(.onlyThisMacSeesThisName)
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
      }
      .formStyle(.grouped)
      .navigationTitle(String(localized: .renameDevice))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: .cancel)) { dismiss() }
            .accessibilityIdentifier("renameCancelButton")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: .rename), action: confirm)
          .accessibilityIdentifier("renameConfirmButton")
        }
      }
      .onAppear {
        name = device?.userName ?? ""
        fieldFocused = true
      }
    }

    private func confirm() {
      model.rename(id, to: name)
      dismiss()
    }
  }
}
