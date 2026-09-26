// HelperInstaller.swift — registering the privileged helper, and unregistering it.
//
// ── The Remove button is not a courtesy ────────────────────────────────────────
//
// `unregister` ships in the same file as `register` and the button is present whenever
// the helper is installed. A person who can install a root daemon from inside an app and
// cannot remove it from the same place has been handed something they do not control,
// and the next thing they do is search for how to delete it by hand.
//
// ── Why the state is read from the system and not remembered ───────────────────
//
// `SMAppService.status` is the registration as `launchd` holds it, and it can change
// without this app: an administrator can disable the item in Login Items, a macOS
// upgrade can require re-approval, an older copy of the app can leave a registration
// behind. Anything this app cached would be a second answer that disagrees with the
// first at exactly the moment somebody is trying to work out what is running.
//
// The one thing status cannot tell us is whether the helper will actually answer, so
// `state()` also asks it. A registration that is `enabled` and a daemon that refuses to
// launch look identical from `status` alone, and `requiresApproval` is a whole state
// where the answer is "it is there and it will not work yet".
import Foundation
import ZhenPrivilege
import ServiceManagement

/// Installing, removing and reporting on the privileged helper.
@MainActor
enum HelperInstaller {
    /// The daemon, as `SMAppService` names it.
    ///
    /// `plistName` is the filename inside `Contents/Library/LaunchDaemons/`, not a path
    /// and not the label. Getting that wrong is the usual cause of error 108, "unable to
    /// read plist", which names the wrong thing: the plist is almost always fine and the
    /// bundle layout or the signature is not.
    static var service: SMAppService {
        SMAppService.daemon(plistName: HelperIdentity.plistName)
    }

    /// What Settings should show.
    static func state() async -> HelperState {
        switch service.status {
        case .enabled:
            // Registered. Ask the daemon what it is, so a stale helper from an older
            // install is visible as a version rather than as a scan that quietly has no
            // ARP in it.
            if let version = await HelperClient.version() {
                return .installed(name: "\(HelperIdentity.label) · version \(version)")
            }
            return .unavailable(reason: """
                The helper is registered but is not answering. Removing it and \
                installing it again usually settles this; scans work without it and \
                will say the layer-2 sweep did not run.
                """)
        case .requiresApproval:
            // Its own state, not `unavailable`. `unavailable` renders the headline
            // "Not installed.", which is false here and contradicts the sentence under
            // it — the app telling somebody to go approve a thing it has just said
            // does not exist.
            return .awaitingApproval(name: HelperIdentity.label)
        case .notFound:
            return .notInstalled
        case .notRegistered:
            return .notInstalled
        @unknown default:
            return .notInstalled
        }
    }

    /// Registers the daemon.
    ///
    /// - Returns: nil when it registered, or a sentence saying why it did not.
    static func install() -> String? {
        do {
            try service.register()
            return nil
        } catch {
            return describe(error)
        }
    }

    /// Unregisters it.
    static func remove() -> String? {
        do {
            try service.unregister()
            return nil
        } catch {
            return describe(error)
        }
    }

    /// Opens the Login Items pane.
    ///
    /// The whole reason `AssociatedBundleIdentifiers` is in the daemon plist: a person
    /// who just installed a background root process should be able to see it, under this
    /// app's name and icon, in the place macOS keeps such things. A claim this app makes
    /// about itself is worth less than the same claim from System Settings.
    static func showInSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Turns an `SMAppService` error into something worth reading.
    ///
    /// Error 108 gets its own sentence because its message names the wrong thing. It
    /// reads as a malformed plist and is almost always a signature problem — the app and
    /// the daemon signed by different teams, an unsigned build, or the plist not where
    /// the bundle layout says it is. Somebody reading "unable to read plist" will go and
    /// check their XML, which is the one place the fault is not.
    static func describe(_ error: any Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 108:
            return """
                macOS could not read the helper's launchd plist (error 108). Despite the \
                wording this is almost never the plist's contents: it means the bundle is \
                not signed, the app and the helper are signed by different teams, or the \
                plist is not at \(HelperIdentity.plistBundlePath) inside the app. A build \
                from Scripts/build-app.sh signs both with one identity and checks they \
                match.
                """
        case 1:
            return """
                The helper was not approved. macOS asks once, in System Settings under \
                General then Login Items; until it is approved, scans run without the \
                layer-2 sweep.
                """
        default:
            return "The helper could not be registered: \(error.localizedDescription) (\(code))."
        }
    }
}
