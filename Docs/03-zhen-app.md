# 03 — `zhen-app`

**Run last.** Both other packages must build and their tests pass first. This one
consumes core exactly as the CLI does and adds nothing to the model.

**Read the design system appendix first — A1, A2, then A3.** It is the visual
source of truth in code form: tokens, components, screen composition and every state.
This document covers wiring and platform work and assumes those three are already
built, so nothing here re-specifies a colour, a metric or a component.

> The package keeps the agreed name, but it ships **macOS first**. Nothing here
> assumes iOS; the parts that could not work there — the privileged helper, BPF —
> are already isolated behind protocols, so an iOS target later is additive.

---

## What this package is

The Apple-platform application: a SwiftUI app bundle, a privileged helper, and the
view models that bind `ZhenCore`'s async streams to a UI. The design canvas is
the visual source of truth for everything on screen; this document covers how it is
wired, not how it looks.

The app links `ZhenCore` **directly**. It does not shell out to `zhen`, it
does not parse the CLI's JSON, and it does not spawn anything — the no-subprocess
rule is absolute and, as the privileged helper explains, it is also what makes that
path defensible.

---

## Bundle identity

Nothing a user can see in System Settings may look anonymous. This is a security
property, not a cosmetic one: a person who cannot tell our background item apart
from malware has no way to make a good decision about either.

```
com.jctec.zhen               Zhen                    the app
com.jctec.zhen.helper        the privileged helper
```

These are not written down here as the authority. `HelperIdentity` in `ZhenPrivilege`
declares them, `Scripts/build-app.sh` repeats them, and a test pins those two to each
other. This document is a third copy that nothing pinned — and for a while after the
2026-09-23 rename it carried the former prefix and a helper name that was never
registered, which is a document sending anyone debugging a failed registration to look
for the wrong label. `Scripts/verify-identifiers.sh` now fails when a document names an
identifier the code does not declare. Read the code when they disagree.

Structure macOS can validate:

```
Zhen.app/Contents/
  Info.plist                      NSLocalNetworkUsageDescription, NSBonjourServices
  MacOS/Zhen
  MacOS/zhen-helper               the daemon executable, same team, same signature
  Library/LaunchDaemons/com.jctec.zhen.helper.plist
```

The launchd plist carries `AssociatedBundleIdentifiers = ["com.jctec.zhen"]`. That
key is what makes Login Items render **"Zhen"** with the app's icon instead of a
bare reverse-DNS string, and it is the difference between a user who feels informed
and one who feels infiltrated.

The app pairs it with an explicit panel before registering anything: what the helper
is, what it can do, what it cannot, and a button calling
`SMAppService.openSystemSettingsLoginItems()` so the claim can be checked against the
OS rather than believed. The helper is registered on demand, never at first launch.

**Distribution: unsandboxed, Developer ID, notarized.** The App Sandbox has no
entitlement covering raw sockets or BPF, and sandboxed multicast requires a managed
entitlement needing Apple's approval. A network scanner is not an App Store app.
This is a decision to hold, not revisit — if sandboxing is ever forced, the design
breaks and needs XPC to an out-of-process helper for everything, not just the
privileged parts.

---

## Screens

Five, from the canvas. Each binds to a stream or a query and owns no networking.

| Screen | View | Bound to |
|---|---|---|
| Devices (dark + light) | `DeviceListView` | store query, live-updated |
| Device detail | `DeviceDetailView` | one `Device` plus its observations and name candidates |
| Activity | `ActivityView` | derived events, filtered by kind and time |
| Live scan | `ScanProgressView` | `AsyncStream<ProbeEvent>` plus `[Degradation]` |
| Settings | `SettingsView` | scan defaults, retention, helper state |

Three things the canvas decided that the implementation must not quietly undo.

**The unidentified device is the acceptance case.** Several hosts have a randomized
MAC and no name, vendor or model. That is a normal row, not an error state, and
empty fields must not collapse the layout. If the list looks wrong when half the
network is anonymous, the app is wrong.

**Degradations are UI, not logs.** They belong on the live-scan screen in plain
language with an action — and they must not evaporate when the scan ends. A run that
completed with partial results says so on the Devices screen too; a green dot over
an incomplete scan is a lie of omission.

**Losing name candidates are shown.** The device detail lists every source that
offered a name and which one won. That panel is the product's argument for itself.

The Omada surfaces drawn in the canvas are **out of scope**. Build the screens
without them; the layout must not depend on that column existing.

---

## Swift 6 in the app

**`.defaultIsolation(MainActor.self)` for this package only.** The inverse of core.
Views, view models and the store's UI-facing queries are main-actor by default and
need no annotation; scanning stays non-isolated in core and is never dragged onto the
main actor by an accidental inference. Getting this backwards is the single most
expensive mistake available here — it would serialize every socket operation behind
the UI and quietly destroy the performance the whole project is for.

**`@Observable`, not `ObservableObject`.** Property-level change tracking means a
list of two hundred devices does not re-render because an unrelated field moved.
With events arriving at hundreds per second, per-property granularity is a
correctness-of-frame-rate issue, not a nicety.

**`.task(id:)` for stream lifetime.** Attach stream consumption to the view, keyed
on the scan identity. SwiftUI cancels the task on disappear or key change, the
cancellation propagates into `AsyncStream.onTermination`, and the sockets close.
Lifetime is structural; there is no `stopScan()` anyone can forget to call.

**Coalesce before you publish.** Bind the UI to a view model that batches stream
events on a display-rate timer, not to the raw stream. The scanner emits far faster
than 60 Hz and SwiftUI will happily try to keep up until it cannot.

**Sendable at the boundary.** Everything crossing from core is a frozen value type
already, so the actor hop is a copy of a struct, not a lock. No `@unchecked
Sendable` in this package; if something needs it, the model is wrong.

---

## The privileged helper

The unprivileged path is the default and must stay fully functional. The helper adds
two things only: a layer-2 ARP sweep that finds hosts answering nothing else, and
SYN scanning. Everything else works without it, and the app must be pleasant for a
user who never installs it.

**Mechanism: `SMAppService.daemon`, XPC over a Mach service.** No setuid binary, no
`sudo` prompt, no subprocess — the invariant survives intact.

Rules the helper is written to:

- **It verifies its caller.** Validate the peer's code signature from the connection
  audit token against a pinned requirement — same team, expected identifier. A Mach
  service is reachable by anything running as the user; without this check the helper
  is a privilege-escalation gadget with our name on it.
- **Its interface is tiny.** "Sweep this network" and "SYN-scan these ports on these
  hosts", both returning results. No arbitrary paths, no arbitrary interfaces, no
  passthrough of anything the caller supplies as a command.
- **It holds no persistent state and opens no files.** It has a socket and an answer.
- **It degrades rather than fails.** `/dev/bpf*` nodes are exclusive-open, and
  Wireshark, `tcpdump`, a VPN client or Little Snitch may hold them. Scan `bpf0..N`
  for a free node; if none, report a degradation and let the unprivileged engine
  carry the scan.
- **It is uninstallable from inside the app**, in one click, next to the install
  control. An installer with no uninstaller is how software earns distrust.

---

## What must be done by hand, why, and how to contain it

### Registration needs a real signing identity

`SMAppService` will not register a daemon the system cannot validate. Ad-hoc signing
limps in local testing and fails properly the moment anyone else runs it.

*Containment:* Developer ID Application certificate, hardened runtime, notarized
distribution. This is a prerequisite, not a build step to discover late — verify it
before writing the helper, because there is no workaround and no amount of code
substitutes for the certificate.

### The helper's plist is hand-written and unvalidated

Nothing checks `AssociatedBundleIdentifiers` at build time. Get it wrong and
registration still succeeds — the item simply shows up in Login Items looking
anonymous, which is the exact failure this whole section exists to prevent.

*Containment:* a test that reads the built app's launchd plist and asserts the key,
the label, and the program path. Ship the check, not the intention.

### SwiftData needs full Xcode, and does not travel

`@Model` and `@ModelActor` are external macros from a compiler plugin that ships
only with full Xcode. Command Line Tools alone cannot build them, and there is no
flag that changes this.

More consequentially: **SwiftData is Darwin-only, and the CLI is supposed to reach
Linux.** These two facts cannot both be satisfied by a single store.

*Ruled on 2026-09-09: the recommendation stands.* Persistence is a protocol in core —
`HistoryStore`, structs in and structs out. This package provides the SwiftData
conformance and the app uses it. The portable conformance, an append-only log with
an index, serves the CLI everywhere. Both write the same model types, so an artifact
from either is readable by both.

Portability wins over "SwiftData only, not even as a cache", and the spec's
requirement is amended to say so. The rule was written before the portability
requirement existed; when the two met, the one that survives is the one that decides
where the project can run. What the rule was protecting against — a second store
appearing as an unaccountable cache beside the first — is protected instead by the
seam: two conformances, one protocol, both writing the same model types, and no
third.

*Ruled again on 2026-09-11: the SwiftData conformance is withdrawn.* The app never
used it. It was wired to the log file `zhen scan` writes, because one shared
file is the only reason the app and the command line agree about the network — a
person who scans in a terminal is entitled to see that network when they open the
app, and a SwiftData database beside the log would make the app's history a second
opinion. That left `SwiftDataHistoryStore` referenced by nothing but its own tests:
two hundred and sixty-five lines, a schema, and a chunk of `AppTests`, maintained
for a conformance that shipped nowhere.

The reasoning above still holds and is not being reversed — it is being applied one
step further. A conformance that ships nowhere is not a second implementation of an
idea, it is a second description of one, and it drifts silently because nothing
runs it. It was also costing the project an Xcode-only macro plugin as a build
prerequisite, and it held the place in the store suite that `LogHistoryStore` — the
conformance the app actually opens — did not have. The suite now runs against the
two that ship: the log and the session-lifetime store the app falls back to when
there is nowhere to write a file.

SwiftData comes back the day something Apple-side needs what it offers and the log
cannot give it — live queries driving a view is the plausible one — and that is a
decision to take with the feature in hand. The seam is what makes it cheap, which
was the argument for having a seam at all.

*Validated 2026-09-09, and the validation is why the withdrawal is cheap.*
`@ModelActor` and `@Model` did build under SwiftPM and run under `swift test` — an
in-memory container and an on-disk one, the latter surviving the container being
closed and reopened. So the question this section exists to answer has an answer,
and it is recorded here rather than having to be rediscovered: SwiftData works in
this project's shape. It is not being withdrawn because it could not be made to
work. Note what it never proved: an xctest bundle is still a bundle, so this says
nothing about SwiftData in a bare executable — which nothing here needs, then or
now.

*Containment either way:* the store is `@ModelActor`, and **a `PersistentModel` never
crosses an isolation boundary** — not because it isn't `Sendable` in this SDK, but
because faulting is executor-bound and an object read on one actor and touched from
another faults on the wrong queue. Structs in, structs out, always.

### The Local Network permission

An app bundle handles this correctly by nature — the grant attaches to the app, under
its own name, with our usage description. That is a real argument for standing the
bundle up early rather than at the end.

*Containment:* every Bonjour service type the discovery layer browses must appear in
`NSBonjourServices`. A type that is browsed but undeclared returns nothing, silently,
with no error anywhere. Generate that array from the same list the code browses so
the two cannot drift.

### Xcode project files are not generated by SPM

The app target needs a bundle, entitlements and an embedded helper — none of which
SPM produces.

*Containment:* one owner for the project file, and everything that can live in a
package does. The app target should be a thin shell over `ZhenCore` plus this
package's views, so the unbuildable-by-SPM surface stays as small as possible.

---

## Acceptance

- With the helper never installed, every screen works and the app is pleasant. This
  is the primary configuration, not a fallback.
- Denying Local Network permission produces a named, actionable degradation on the
  live-scan screen — not an empty list.
- The device list renders correctly when every host is unidentified.
- Login Items shows "Zhen" with the app's icon. Verified on a clean machine, by
  a person, once — screenshots in the PR.
- The helper refuses a connection from an unsigned or wrongly-signed caller. Test it
  with a deliberately mis-signed harness; a security control that has never been
  observed failing correctly has not been tested.
- Uninstalling the helper from the app leaves nothing in Login Items.
- No `@unchecked Sendable`, no `fatalError` on a reachable path, no scanning work on
  the main actor — the last verifiable by an instrument trace during a full scan.

---

## Bibliography

**Marinos, I., Watson, R. N. M., & Handley, M. (2014). Network Stack Specialization
for Performance. *ACM SIGCOMM '14*.** Cambridge / UCL.
<https://www.cl.cam.ac.uk/research/security/ctsrd/pdfs/201408-sigcomm2014-specialization.pdf>
Domain transitions and buffering are where performance goes. The app's XPC boundary
is exactly such a transition, which is why the helper's interface is coarse — sweep a
network, scan a set of ports — rather than a chatty per-probe protocol that would pay
the crossing tens of thousands of times.

**Grosvenor, M. P., Schwarzkopf, M., Gog, I., Watson, R. N. M., Moore, A. W., Hand,
S., & Crowcroft, J. (2015). Queues Don't Matter When You Can JUMP Them! *USENIX
NSDI '15*.** Cambridge.
<https://www.usenix.org/system/files/conference/nsdi15/nsdi15-paper-grosvenor.pdf>
Unbounded queueing destroys tail latency. The event-coalescing view model is this
result applied to a UI: an unbounded stream feeding SwiftUI produces a frame-time
tail that a bounded, display-rate batch does not.

**Moore, A. W., Hall, J., Kreibich, C., Harris, E., & Pratt, I. (2003). Architecture
of a Network Monitor. *PAM '03*.** Cambridge.
<https://www.cl.cam.ac.uk/research/srg/netos/projects/archive/nprobe/publications/pam2003moore.pdf>
Capture separated from analysis, with timestamps taken as close to the wire as
possible. The app renders; it never measures. Anything the UI displays as a duration
was timed in core.

**Antichi, G., et al. (2014). OSNT: Open Source Network Tester. *IEEE Network*,
28(5).** Cambridge / QMUL.
<https://www.cl.cam.ac.uk/~nz247/publications/antichi2014osnt.pdf>
An instrument states its own accuracy. When the app shows an RTT or a scan duration,
it shows the measurement core recorded, at the precision core recorded it — no
re-rounding in a formatter that makes a 0.4 ms answer look like 0 ms.

**Myers, E. W. (1986). An O(ND) Difference Algorithm and Its Variations.
*Algorithmica*, 1(2).**
The diff algorithm underneath list reconciliation. Stable, correctly-keyed identity
turns a device-list update into O(ND) on the actual change; unstable identity makes
every update a full teardown and rebuild. This is why `Device` identity must be the
store's stable id and never the IP address, which moves.

**Chambi, S., Lemire, D., Kaser, O., & Godin, R. (2016). Better Bitmap Performance
with Roaring Bitmaps. *Software: Practice and Experience*, 46(5).**
<https://arxiv.org/abs/1402.6407>
The activity timeline's underlying question — was this host present at each of the
last N runs — is a bitmap query. Roaring keeps it compressed and directly queryable,
so drawing a 48-hour strip does not mean decompressing a day of observations.

**Cormode, G., & Muthukrishnan, S. (2005). An Improved Data Stream Summary: The
Count-Min Sketch and Its Applications. *Journal of Algorithms*, 55(1).** Warwick.
<https://dsf.berkeley.edu/cs286/papers/countmin-latin2004.pdf>
Fixed-space frequency estimation for the histogram above the activity list. Exact
counts over an unbounded event history grow without limit; a sketch answers the
same visual question in constant space with a bounded, statable error.

**Miller, R. B. (1968). Response Time in Man-Computer Conversational Transactions.
*AFIPS Fall Joint Computer Conference*.**
The thresholds the live-scan screen is designed against: about 100 ms to feel
instantaneous, about 1 s to keep a train of thought unbroken, about 10 s before
attention goes elsewhere. First host on screen inside 100 ms is why discovery
streams rather than returning a complete result — and it is the whole reason the
streaming API in core exists alongside the terminal one.
