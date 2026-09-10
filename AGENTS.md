# Project conventions

## Directory layout

- Ordinary repository directories use lowercase names; separate multiple words with hyphens.
- Application sources live in `src/app/`, Finder extension sources in `src/finder-extension/`, and shared sources in `src/shared/`.
- Keep application entry files directly in `src/app/`; use `stores/` and `views/` for their respective responsibilities.
- Shared platform-independent logic lives in `src/shared/core/`; macOS integration lives in `src/shared/platform/`.
- Tests live in `tests/core/`, `tests/behavior/`, and `tests/release-scripts/`.
- Configuration lives in `config/`, documentation in `docs/`, and scripts in `script/`.
- Keep Swift filenames aligned with their primary type. Preserve tool-defined names such as `Package.swift`, `README.md`, `AGENTS.md`, `OneClick.xcodeproj`, and hidden tool directories. Generated build artifacts and Xcode-managed internal directories are exempt from the lowercase rule.

## Skills and plugins

- Adapt skill/plugin directory examples to this project layout. Do not create root `App/`, `Views/`, `Sources/`, `Tests/`, `Docs/`, `Scripts/`, or script directories under source directories.
- Superpowers documents belong in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- The macOS build/run entrypoint remains `script/build_and_run.sh`; the Codex Run action uses that path.
- Preserve the existing app, extension, and shared-code boundaries; create additional directories only when needed.

## Build and verification

- Generate the committed Xcode project with `python3 script/generate_project.py` after changing project paths or settings. Update the generator rather than only editing the generated project.
- SwiftPM uses explicit paths in `Package.swift`; keep them synchronized with source moves.
- Run `./script/check.sh --build` for Swift tests, release-script tests, shell syntax checks, and an unsigned app/extension build without launching the app. In a nested sandbox, append `--disable-sandbox` for SwiftPM.
- Keep local signing configuration in ignored `config/Local.xcconfig`.
