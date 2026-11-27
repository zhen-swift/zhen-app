import SwiftUI

/// The one question before every network's history is erased, wherever it was asked for:
/// Settings, or the File menu.
///
/// A `confirmationDialog`, because the system's grammar for an action that cannot be undone
/// is exactly this: the destructive button named for what it does, and Cancel.
struct EraseHistoryConfirmation: ViewModifier {
  @Binding var isPresented: Bool
  let model: NetworkModel

  func body(content: Content) -> some View {
    content
      .confirmationDialog(
        String(localized: .eraseAllHistoryQuestion), isPresented: $isPresented, titleVisibility: .visible
      ) {
        Button(String(localized: .eraseAllHistory), role: .destructive) {
          Task { await model.eraseAllHistory() }
        }
        .accessibilityIdentifier("confirmEraseHistoryButton")
      } message: {
        Text(.eraseAllHistoryDetail)
      }
  }
}

extension View {
  /// Asks before erasing every network's history, while `isPresented`.
  func eraseHistoryConfirmation(isPresented: Binding<Bool>, model: NetworkModel) -> some View {
    modifier(EraseHistoryConfirmation(isPresented: isPresented, model: model))
  }
}
