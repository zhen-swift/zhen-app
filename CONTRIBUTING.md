# Contributing

## Setting up

- macOS 26 and Xcode 26. The project targets macOS 26 and its tests run the app locally.
- Ruby 4.0 with Bundler, for fastlane: `bundle config set --local path vendor/bundle &&
  bundle install`.
- **No Apple Developer account is needed to build and test.** The fastlane lanes sign ad
  hoc (`CODE_SIGN_IDENTITY=-`, an empty team). Running from Xcode uses automatic signing:
  select your own team on the Zhen target, and do not commit that change.
- The UI tests drive the app, so macOS asks once for Accessibility and Automation access
  for Xcode or your terminal. Grant it in System Settings › Privacy & Security.
- The engine is [zhen-core](https://github.com/zhen-swift/zhen-core), resolved by version
  from GitHub. Nothing needs to be checked out beside this repository.

## Changes

1. Read `AGENTS.md`, the house rules. They win over every other document here.
2. One change per pull request. A change that needs a new zhen-core is two pull requests:
   zhen-core first, then this repository adopting the release.
3. `bundle exec fastlane test` passes locally before you push; CI runs the same command.
4. A behaviour change updates `Docs/` in the same pull request, and adds a line under
   **Unreleased** in `CHANGELOG.md`.
5. A test that guards a rule is first shown failing on a deliberate break, then passing.
   Say what the break was in the pull request.
6. Nothing from a real network is committed. Fixtures come from
   `Scripts/anonymise-scan.py`, and `--verify` proves it.
7. A change to the screens needs new screenshots (`Docs/SCREENSHOTS.md`); say so in the
   description rather than regenerate them in an unrelated pull request.

Conduct: `CODE_OF_CONDUCT.md`. Security reports: `SECURITY.md`.

## Licence

By contributing you agree your contribution is licensed under the Apache License 2.0,
the same as the rest of the work, including the patent grant in section 3. No separate
contributor licence agreement is required.
