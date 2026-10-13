# Contributing

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
