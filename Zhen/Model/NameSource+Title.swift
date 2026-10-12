import Foundation
import ZhenCore

extension NameSource {
  /// The source as the card names it.
  var title: String {
    switch self {
    case .administrative: String(localized: .assigned)
    case .mdns: String(localized: .bonjour)
    case .ssdp: String(localized: .upnp)
    case .netbios: String(localized: .netbios)
    case .dns: String(localized: .reverseDns)
    }
  }
}
