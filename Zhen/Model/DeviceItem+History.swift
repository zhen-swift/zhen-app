import Foundation
import ZhenCore

/// One name a source offered for a device, as "Known by" lists it.
nonisolated struct NameOffer: Hashable, Sendable {
  let source: NameSource
  /// Nil when the source offered nothing: the absence is shown, not hidden.
  let value: String?
  let isWinner: Bool
  /// The first offer from its source carries the source's label; the rest sit under it.
  let isFirstOfSource: Bool
}

nonisolated extension DeviceItem {
  /// Every name every source offered, by source in core's order, best first within each.
  ///
  /// Every candidate, not one per source: a device that answers Bonjour as two names has
  /// told us two things, and "Known by" is where a person checks what the network said
  /// (A3; it showed only the first until phase 3). The same value repeated by one source,
  /// at different ranks, is one offer.
  var nameOffers: [NameOffer] {
    let best = device.names.best
    return NameSource.allCases.flatMap { source -> [NameOffer] in
      var seen: Set<String> = []
      let offered = device.names
        .filter { $0.source == source }
        .sorted()
        .filter { seen.insert($0.value).inserted }
      guard !offered.isEmpty else {
        return [NameOffer(source: source, value: nil, isWinner: false, isFirstOfSource: true)]
      }
      return offered.enumerated().map { index, candidate in
        NameOffer(
          source: source, value: candidate.value,
          isWinner: userName == nil && candidate.source == best?.source && candidate.value == best?.value,
          isFirstOfSource: index == 0
        )
      }
    }
  }

  /// The identity card's caption: which key holds this record together, and how well.
  ///
  /// "identity key: rotating MAC, stabilised by Bonjour name" — A3's sentence, built from
  /// core's key kind and `identityStability`. It replaces a raw `stability moderate`.
  var identityCaption: String {
    // The lease key's value depends on the network; its kind, which is all this reads, does not.
    let network = IPv4Network(base: device.ipv4Addresses.first ?? IPv4Address(raw: 0), prefix: 32)
    let kinds = HostIdentifier.candidates(for: device, in: network).map(\.kind)
    let key: String = switch kinds.first {
    case .universalMAC?: String(localized: .hardwareMac)
    case .randomizedMAC?: String(localized: .rotatingMac)
    case .mdnsInstance?: String(localized: .bonjourName)
    case .dhcpHostname?: String(localized: .dhcpName)
    case .ipLease?, nil: String(localized: .addressOnly)
    }
    let holding: String = switch device.identityStability {
    case .strong: String(localized: .permanent)
    case .moderate:
      kinds.contains(.mdnsInstance)
        ? String(localized: .stabilisedBonjourName)
        : String(localized: .stabilisedDhcpName)
    case .weak: String(localized: .splitsWhenMacRotates)
    case .ephemeral: String(localized: .holdsOnlyWhileLeaseDoes)
    }
    return String(localized: .identityKey(key, holding))
  }
}

nonisolated extension DerivedEvent.Kind {
  /// Whether this kind is about who a device is, rather than whether it is here.
  var isIdentityChange: Bool {
    switch self {
    case .merged, .renamed, .ipChanged: true
    case .appeared, .disappeared: false
    }
  }
}
