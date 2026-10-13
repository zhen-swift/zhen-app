# CI

| Workflow | Trigger | Runs | Artifacts |
|---|---|---|---|
| `ci.yml` | push to `main`, every PR, by hand; a superseded PR run is cancelled, a `main` run never is | `tokens` (Linux, 5 min): `check-tokens.sh --self-test`, then `check-tokens.sh`. `docs` (Linux, 5 min): `check-docs.sh`, every path the documents name exists. `app` (`macos-26`, 60 min): `generate-bonjour-services.sh --check`, then `bundle exec fastlane test` | `test-output` (`fastlane/test_output`), 14 days, always |
| `screenshots.yml` | by hand, `v*` tags | `bundle exec fastlane marketing`: render from committed captures. With none committed it says so in a notice and renders nothing | `appstore-assets` 30 d, `readme-artwork` 30 d, `raw-captures` 14 d |

- Local commands are CI's commands. The only CI-only setting is `SPM_CACHE_PATH`, which
  points `scan` at a cached SwiftPM checkout keyed on `Package.resolved`.
- No secrets, no App Store Connect, no signing identity: every job signs ad hoc, so forks
  run CI unchanged. The token is read-only (`permissions: contents: read`).
- zhen-core is resolved from GitHub by version on every run, in a fresh directory for the
  Bonjour check. A version that does not exist as a tag fails here first.
- `screenshots.yml` renders but does not capture. A Mac capture must be 2880 × 1800, and a
  1× runner's are undersized (`Docs/SCREENSHOTS.md`).
- Workflows never commit back. Download the artifacts, review them, commit deliberately.
- `Gemfile.lock` lists `arm64-darwin-25`, `arm64-darwin-26`, `x86_64-darwin` and `ruby`.
