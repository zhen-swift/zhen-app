import Foundation
import ZhenCore

extension NameSource {
  /// The source as the card names it.
  var title: String {
    switch self {
    case .administrative: String(localized: "Assigned")
    case .mdns: String(localized: "Bonjour")
    case .ssdp: String(localized: "UPnP")
    case .netbios: String(localized: "NetBIOS")
    case .dns: String(localized: "Reverse DNS")
    }
  }
}
