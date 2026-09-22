# OneClick project guidance

OneClick is a macOS Finder utility: a SwiftUI settings app and an embedded
Finder Sync extension. Open/copy actions run in the extension; closing settings
quits the app. Both processes share data outside containers.

## Working conventions

- Finish the requested work and proportional verification. Disposable local tests
  need no repeated approval. Small edits need no plan document or review checkpoint.
- Keep process/platform boundaries: `src/app/`, `src/finder-extension/`,
  `src/shared/core/`, `src/shared/platform/`. Use type-matching Swift filenames
  and lowercase, hyphen-separated directories, except tool-defined names.
- Use static icons in `assets/`, including `Assets.xcassets`. Do not redraw them
  or add a generation pipeline. Change project settings in `script/generate_project.py`
  and regenerate; Swift source additions in synchronized groups need no project edit.
  Keep explicit `Package.swift` paths aligned with moves.
- Builds use ad hoc signing (`CODE_SIGN_IDENTITY=-`, empty `DEVELOPMENT_TEAM`).
  Leave ignored `config/Local.xcconfig` untouched. Write historical team IDs as `<Team ID>`.
- Keep scripts small: build/run, check, project generation, release, uninstall.
  Avoid wrapper chains and extra modes without a concrete need.

## Relevant guides

- Setup and script changes: [Contributing](CONTRIBUTING.md).
- Processes, permissions, shared storage, menus: [Runtime constraints](docs/runtime-invariants.md).
- Tests and desktop evidence: [Testing](docs/testing.md), [verification](docs/verification.md).
- Signing, DMG, CI/CD, Cask: [Releasing](docs/releasing.md).
- Installation and usage: [README](README.md).

## Verification

Documentation: inspect links/commands and run `git diff --check`.
Code: `./script/check.sh`; add `--build` for app, extension or build configuration.
Other flags pass to SwiftPM (`--filter FinderMenuTests`, `--disable-sandbox`).
Build/run integration: `./script/build_and_run.sh`.
Record substantive findings in `docs/implementation-log.md`, desktop evidence in
`docs/verification.md`. If a task needs specs or plans, use `docs/superpowers/`.
