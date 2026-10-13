# Documentation

Reference documentation for the app: what is true of it now.

| | |
|---|---|
| `../AGENTS.md` | The house rules: **how** the app is written. Wins over every document here |
| `ARCHITECTURE.md` | **How the app fits together**, its deviations from the house rules, and its known rough edges |
| `TESTING.md` | The test layers, the fixture network, and the commands that run them |
| `CI.md` | The workflows, what each job checks, and what it needs |
| `SCREENSHOTS.md` | The artwork pipeline: showcase data, captures, and the marketing assets |
| `APP_STORE.md` | Distribution: Developer ID and notarisation, not the Mac App Store, and why |
| `PRIVACY.md` | What the app does with what it sees |
| `../Zhen/Zhen.docc` | The design system as DocC: foundations, components, and building a screen. `bundle exec fastlane docc` builds it |

The engine — scanning, naming, history, the privileged helper — is documented in
[`zhen-core`](https://github.com/zhen-swift/zhen-core).
