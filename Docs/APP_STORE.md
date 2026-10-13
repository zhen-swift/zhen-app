# Distribution

Zhen ships **outside the Mac App Store**: Developer ID signed, hardened runtime, notarised.
The App Sandbox has no entitlement for raw sockets or `/dev/bpf*`, which the scanner and
its privileged helper need. The app is unsandboxed on purpose. `InfoPlistTests.appIsNotSandboxed` pins it.

## Building a release

```
Scripts/release.sh "Developer ID Application: <Name> (S8662L649U)" zhen-notary
# or
bundle exec fastlane release identity:"Developer ID Application: <Name> (S8662L649U)"
```

The script:
1. resolves the pinned zhen-core
2. builds the app (Release); Xcode's Embed Helper phase builds zhen-core's `zhen-helper`
   product from that same checkout and embeds it
3. signs inside-out: the helper under its daemon identifier, then the app
4. verifies the signatures, the hardened runtime, the team and the daemon plist
5. notarises, staples and asks Gatekeeper

The notary password lives in the keychain profile made once by
`xcrun notarytool store-credentials zhen-notary`. Nothing in the repository holds a
credential. `Scripts/release.sh - --no-notarize` is the ad-hoc dry run.

## Store artwork

`AppStoreAssets/` holds upload-ready 2880 × 1800 images, plain and captioned, rendered
from `Marketing/copy.json` (`Docs/SCREENSHOTS.md`). They serve the website and README
today, and a store listing if distribution ever changes.

## Before a release

Some checks only a person with the Developer ID can run, because CI has no identity and
no administrator: notarisation, helper registration and Login Items, a mis-signed caller
refused (`Tools/MisSignedCaller`), removal, a real-LAN scan, and the main-thread trace.
