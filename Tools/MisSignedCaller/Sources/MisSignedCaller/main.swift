import Foundation
import ZhenPrivilege

// Asks the helper what it is, as the app does, and reports whether it answered.
//
// Exit 0 — REFUSED: nothing answered. This is the pass, *if* the real app's Settings shows
//   "Installed · Zhen Scan Engine <version>" at the same moment (the positive control: the
//   helper is up and answers a correctly signed caller).
// Exit 1 — ANSWERED: the helper served a caller it should have refused. A security failure.
let version = await HelperClient.version()
if let version {
  print("ANSWERED: helper \(version) served a caller signed as \(Bundle.main.bundleIdentifier ?? "(no bundle id)") — the requirement is not enforced")
  exit(1)
}
print("REFUSED: no answer from \(HelperIdentity.label)")
print("Pass only if Zhen's Settings shows the helper installed and answering right now.")
exit(0)
