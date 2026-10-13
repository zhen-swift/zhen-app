import SwiftUI
import ZhenCore

/// Activity's segments. Copy frozen by the designer's round 2: Presence (was Appearances),
/// Addresses (was Network). Filtering by device is the search field, never a sixth segment.
enum ActivityFilter: String, CaseIterable, Identifiable, Hashable {
  case all, presence, identity, ports, addresses

  var id: Self { self }

  var title: LocalizedStringResource {
    switch self {
    case .all: .all
    case .presence: .presence
    case .identity: .identity
    case .ports: .ports
    case .addresses: .addresses
    }
  }

  /// The noun in "No ⟨kind⟩ events in this window".
  var noun: String {
    switch self {
    case .all: ""
    case .presence: String(localized: .presenceLower)
    case .identity: String(localized: .identityLower)
    case .ports: String(localized: .port)
    case .addresses: String(localized: .address)
    }
  }

  func includes(_ kind: DerivedEvent.Kind) -> Bool {
    switch self {
    case .all: true
    case .presence: kind == .appeared || kind == .disappeared
    case .identity: kind == .renamed || kind == .merged
    case .ports: kind == .portOpened || kind == .portClosed
    case .addresses: kind == .ipChanged
    }
  }
}
