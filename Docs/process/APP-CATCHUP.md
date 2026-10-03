# App catch-up — what the CLI run changed under `zhen-app`

The `reorg` CLI run (stages 0, C2, C3, D1, D2, D3) changed APIs the app consumes and did
not build the app. This is the list phase E works from: every such API, what it was, what
it is, and the fix. Written as each stage landed, not reconstructed afterwards.

How the list was made: for each changed declaration, `grep -rn` over `zhen-app/` for its
name. A change with no hit in `zhen-app/` is not listed.

## Stage 0

Nothing the app consumes. `PortScanType`'s `ExpressibleByArgument` conformance lives in
the `zhen` executable, which the app does not link; the test changes are test-only.

## Stage C2 — `Device.ip` is gone (schema 3)

Every site found by `grep -rnE '\.ip\b' zhen-app --include='*.swift'`, then read to see
which type it was on. `HostFacts.ip` is **unchanged** (still `IPv4Address`), so
`AppModel.swift:314`, `:338`, `:419`, `:424` — which read `HostFacts` findings — need
nothing. `Device(observing:in:firstSeen:lastSeen:)` is unchanged, so the test helpers that
build devices that way (`AppTests.swift:134`, `:313`, `:473`) compile as they are.

| Where | Was | Is | Fix |
|---|---|---|---|
| `Zhen/Model/Presentation.swift:31` | `Set(stored…map(\.device.ip))`, a `Set<IPv4Address>` | `Device.primaryAddress: IPAddress` | `Set(stored.filter(\.isPresent).flatMap(\.device.ipv4Addresses))` — keeps `addressesInUse: Set<IPv4Address>` and makes a reassigned v4 lease on any address count |
| `Zhen/Model/Presentation.swift:46` | `ip: device.ip.description` | — | `ip: device.primaryAddress.description` |
| `Zhen/Model/Presentation.swift:67` | `addressesInUse.contains(stored.device.ip)` | — | `stored.device.ipv4Addresses.contains(where: addressesInUse.contains)` |
| `Zhen/Model/Presentation.swift:127` | `KeyValuePair("IP address", device.ip.description, …)` | — | `device.primaryAddress.description`; or one pair per `device.addresses.sorted()` when the detail view is ready to show v6 |
| `Zhen/Model/Presentation.swift:134` | `device.mac?.description ?? device.ip.description` | — | `?? device.primaryAddress.description` |
| `Zhen/Model/Presentation.swift:303` | `"ip:\(device.ip)"` | — | `"ip:\(device.primaryAddress)"` — identical text for every v4 device, so row identities do not churn |
| `ZhenTests/AppTests.swift:404` | `$0.device.ip.description` | — | `$0.device.primaryAddress.description` |
| (anything constructing `Device(ip:…)` directly) | `Device(ip: IPv4Address, …)` | `Device(addresses: Set<IPAddress>, …, vlan: UInt16? = nil, …)` | `Device(addresses: [.v4(ip)], …)`. None found in the app today |
| (anything reading `ScanEvent.ip`) | `IPv4Address` | `IPAddress` | `.description` is unchanged; `event.ip.v4` where an `IPv4Address` is needed. None found in the app today |
| (anything sorting devices by `.ip`) | `$0.ip < $1.ip` | — | `$0.primaryAddress < $1.primaryAddress` — v4 order is unchanged |

Not a compile break, but a behaviour the app will meet:

- **`PortObservation.address: IPAddress?`** is new, and set on every port in a report. The
  memberwise init gained a trailing `address:` parameter with a default, so existing calls
  compile.
- **`Device.fusing(_:)`** now runs in `ScanRunner` (in `zhen/Sources/ZhenScan`) as it does in
  the CLI, so a host seen at a v4 and v6 addresses arrives as one device. Nothing produces v6
  devices before stage D, so the app sees no difference yet.
- **The history store writes schema-3 device lines.** An app build from before this commit
  cannot decode them, skips them, and — if it compacts — rewrites the file without them.
  Rebuild the app on this commit before pointing it at a store the new CLI has written. See
  `Docs/process/V6-questions.md`, Q1.

## Stage C3 — UDP

Nothing the app consumes. `grep -rnE 'PortSpec|EngineCapabilities|SSDPSocket|NetBIOSSocket|NetBIOSDatagram|SSDPDatagram|udpPorts|PortScanResult' zhen-app --include='*.swift'` finds no hit.

For when it does:

- `PortSpec` gained `udpPorts: [UInt16]`; `PortSpec(_:)` still works (`udp:` defaults to
  `[]`). `ports` still means TCP.
- `EngineCapabilities.udpScan` (`"udp_scan"`) is new. A `switch` over capability names
  would need a case; nothing in the app switches over them today.
- `DarwinScanner.udpPorts` is a new member; `ScanRunner` does not use it.

## Stage D1 — ICMPv6 echo

Nothing the app consumes. `ICMPv6Echo` (ZhenCore) and `ICMPv6Socket`/`ICMPv6Ping`
(ZhenDarwin, internal) are new; no existing declaration changed.

## Stage D3 — the IPv6 neighbour cache

No compile break. New, for when the app wants v6 hosts too:

- `IPv6NeighborCache` / `IPv6NeighborEntry` (ZhenCore) and `DarwinNeighborCache`'s
  conformance (`ipv6Entries()`).
- `Device(neighbor:seen:)` (ZhenCore).
- **`ScanRunner` does not read the cache.** To match the CLI, read
  `DarwinNeighborCache().ipv6Entries()` after discovery, keep entries with
  `!isPermanent && address.zone == interface.name`, and add
  `entries.map { Device(neighbor: $0, seen: finishedAt) }` to the array passed to
  `Device.fusing` — the same three lines as `ScanPipeline.swift`'s assembly.
- A device list can now contain devices with **no v4 address**. Anything in the app that
  assumes `primaryAddress.v4 != nil` will show them wrongly (see the C2 table).

## Stage P1 — the port-scanning seam takes `IPAddress` (CLI-v1 run)

No compile break: `grep -rn 'PortScanResult\|PortScanning\|\.ports\.scan\|udpPorts'`
over `zhen-app/` finds nothing — the app reaches port scanning only through
`ZhenScan.ScanRunner`, which is in the `zhen/` package and was updated in the same
commit. Recorded because the public API changed:

| Declaration (ZhenCore) | Was | Is |
|---|---|---|
| `PortScanning.scan(_:ports:…)`, `.stream(_:ports:…)` | `targets: [IPv4Address]` | `[IPAddress]` — pass `.map(IPAddress.v4)` for a v4 list |
| `PortScanResult.ports` | `[IPv4Address: [PortObservation]]` | `[IPAddress: [PortObservation]]` |
| `PortScanResult.fingerprints` | `[IPv4Address: OSFingerprint]` | **unchanged** — a fingerprint comes from the SYN engine, which is v4-only |
| new: `PortScanResult.ipv4Hosts` | — | the v4 hosts and their observations, in address order: what `HostFacts`, still v4-keyed, can hold |
| new: `IPv4OnlyTargets` | — | how an engine that cannot probe v6 names what it skipped, as a degradation |

`ScanRunner.swift` now passes `facts.keys.sorted().map(IPAddress.v4)` and reads
`result.ipv4Hosts`. If the app ever calls an engine directly, those are the two changes.

## Stages P2–P4 — IPv6 port scanning (CLI-v1 run)

No compile break; `grep -rn 'UDPDatagram\|UDPProbe\|FamilyRoutedPortScan\|withSocketAddress'`
over `zhen-app/` finds nothing. Behaviour the app inherits through `ZhenScan`, which builds
its scanner with `DarwinScanner.make`:

- The connect and UDP engines scan v6 targets. `ScanRunner` still passes v4 targets only
  (`facts` is v4-keyed), so nothing changes for the app until it passes v6 addresses.
- Under `auto` **with a capture device**, the port engine is now
  `FamilyRoutedPortScan(v4: <SYN stack>, v6: <connect + banners>)`. With v4 targets only it
  is exactly the SYN stack — same descriptor, same calls — so an app scan is unchanged.
- An open port on a v6 address carries **no service identity**, and the result carries a
  degradation saying identification was not attempted. A detail view should show the
  port as open with an empty service, not as "unknown service".
- `UDPDatagram.source` is `IPAddress` (was `IPv4Address`); internal to `ZhenDarwin`.

## Stage D2′ — `ff02::1` as a complementary source (CLI-v1 run)

No compile break (`grep -rn 'Device(neighbor\|IPv6MulticastEcho'` over `zhen-app/`:
nothing). New in ZhenCore, for when the app wants it: `IPv6MulticastEcho`,
`IPv6Solicitation`, `NoIPv6MulticastEcho`; `Device(neighbor:seen:answeredEcho:)` — the new
parameter defaults to `false`, which is D3's behaviour exactly. `DarwinMulticastEcho` in
ZhenDarwin. **`ScanRunner` does not solicit**, as it does not read the NDP cache (D3 entry
above); to match the CLI, start `DarwinMulticastEcho().solicitAllNodes(on:within:)` beside
discovery and pass `answeredEcho: responders.contains(entry.address)` when building the
neighbour devices.
