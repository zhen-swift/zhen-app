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
        TextField("Name", text: $name, prompt: Text(device?.device.displayName ?? "Unidentified device"))
          .focused($fieldFocused)
          .onSubmit(confirm)
          .accessibilityIdentifier("renameField")
        Text("Only this Mac sees this name. It wins over every name the device announces.")
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
      }
      .formStyle(.grouped)
      .navigationTitle("Rename Device")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("renameCancelButton")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Rename", action: confirm)
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
