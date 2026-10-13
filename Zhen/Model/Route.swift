import Foundation

/// Every screen the detail column can push. Adding a screen is adding a case.
enum Route: Hashable, Codable {
  case device(DeviceItem.ID)
}
