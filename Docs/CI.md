# CI

| Workflow | Trigger | Runs | Artifacts |
|---|---|---|---|
| `ci.yml` | push to `main`, every PR, by hand; superseded runs cancelled | `Scripts/check-tokens.sh` on Linux; on `macos-26`, `generate-bonjour-services.sh --check` then `bundle exec fastlane test` | `test-output` (`fastlane/test_output`), 14 days, always |
| `screenshots.yml` | by hand, `v*` tags | `bundle exec fastlane marketing`: render from committed captures | `appstore-assets` 30 d, `readme-artwork` 30 d, `raw-captures` 14 d |

- Local commands are CI's commands. The only CI-only setting is `SPM_CACHE_PATH`, which
  points `scan` at a cached SwiftPM checkout keyed on `Package.resolved`.
- No secrets, no App Store Connect, no signing identity: every job signs ad hoc, so forks
  run CI unchanged.
- `screenshots.yml` renders but does not capture. A Mac capture must be 2880 × 1800, and a
  1× runner's are undersized (`Docs/SCREENSHOTS.md`).
- Workflows never commit back. Download the artifacts, review them, commit deliberately.
- `Gemfile.lock` lists `arm64-darwin-25`, `arm64-darwin-26`, `x86_64-darwin` and `ruby`.

**Status (2026-10-11):** the branch carrying these workflows has not been pushed, so
neither has run on GitHub. `macos-26` as a runner label is an assumption the first run
will test.
