## What this changes, and why

<!-- The reasoning matters more than the diff. If it changes what a person sees, say
     which room, and attach a before and after. -->

## Checks

- [ ] `bundle exec fastlane test` passes (unit and UI tests); CI runs the same command
- [ ] `./Scripts/check-tokens.sh` passes: no literal colour, size or spacing in a view
- [ ] `./Scripts/check-docs.sh` passes: every path the documents name exists
- [ ] `./Scripts/generate-bonjour-services.sh --check` passes if zhen-core's version changed
- [ ] A test that guards a rule was shown failing on a deliberate break first. The break:
- [ ] `Docs/` and the **Unreleased** section of `CHANGELOG.md` are updated if behaviour changed

## The rules this repository does not bend

- [ ] Nothing from a real network is committed. Fixtures come from `Scripts/anonymise-scan.py`
- [ ] No scanning on the main actor. `@unchecked Sendable` and `nonisolated(unsafe)` only with the invariant in a comment; no force unwrap or `try!` unless genuinely unrecoverable (AGENTS.md)
- [ ] A new zhen-core is adopted by version, in its own pull request, after the core release

## What you could not verify

<!-- Say it plainly: an appearance, a window size, the helper, a real network. An
     untested path named here is worth more than a checkbox ticked on trust. -->
