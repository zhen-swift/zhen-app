import Darwin

/// Which networks this Mac is on, as one comparable string: every up, non-loopback IPv4
/// interface's name, address and mask.
///
/// Core fixes a scan engine's interface and network when the engine is built. Moving from
/// one network to another — same `en0`, different subnet — left a cached engine sweeping
/// the old one, and its empty run marked every known device as gone in the shared history
/// (review, part 7). Reading this is a `getifaddrs` walk: microseconds, unlike building an
/// engine.
nonisolated enum NetworkFingerprint {
  static func current() -> String {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return "" }
    defer { freeifaddrs(head) }
    var entries: [String] = []
    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let entry = pointer.pointee
      let flags = Int32(entry.ifa_flags)
      guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
            flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
      entries.append("\(String(cString: entry.ifa_name))|\(describe(address))|\(entry.ifa_netmask.map(describe) ?? "")")
    }
    return entries.sorted().joined(separator: ";")
  }

  private static func describe(_ address: UnsafeMutablePointer<sockaddr>) -> String {
    address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { String($0.pointee.sin_addr.s_addr) }
  }
}
