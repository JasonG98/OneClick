# Directory Layout Implementation Plan

**Goal:** Apply the user-approved lowercase directory layout without changing application behavior or losing existing uncommitted work.

**Architecture:** Keep the app, Finder extension and shared code boundaries. Move source into `src/`; retain explicit SwiftPM source selection and regenerate the Xcode project from its generator.

**Tech Stack:** Swift, SwiftPM, Xcode, shell scripts.

**Spec:** The approved directory design in this conversation: `src/app`, `src/finder-extension`, `src/shared`, `tests`, `config`, `docs`, `script`. Ordinary nested directories use lowercase kebab-case; tool-defined names and Swift filenames retain their spelling.

## Constraints

- Preserve all existing working-tree edits and untracked source/test files.
- Keep application, target, scheme, bundle and Swift type names unchanged.
- Keep `docs/` and `script/` as plugin-compatible output locations.
- Do not launch the app or restart Finder for this layout change.

## Tasks

- [x] Move app entry files directly into `src/app/`, stores/views into lowercase subfolders; move Finder and shared sources; lowercase config and test directories.
- [x] Update generator paths, SwiftPM target paths, scripts, ignore rules and documentation. Regenerate the Xcode project. Check the existing Codex Run action remains valid.
- [x] Add root `AGENTS.md` documenting naming and plugin adaptation rules; update README structure.
- [x] Verify source hashes against the pre-migration snapshot, inspect stale paths and directory casing, and run `./script/check.sh --build --disable-sandbox` to verify Swift tests, release-script tests and unsigned app/extension builds.

## Verification results

- 42 Swift/configuration files match the pre-migration working-tree hashes exactly.
- All ordinary directories use lowercase; no old path references remain in scripts, manifest, README or documentation.
- `./script/check.sh --build --disable-sandbox`: 64 Swift tests and 6 release-script tests passed; unsigned arm64 app and Finder extension build passed. Xcode required execution outside the agent sandbox because the sandbox blocked Swift macro plugin startup.
- `git diff --check` and `git diff --cached --check` passed.
- Recorded the case-only `Config` → `config` rename in the Git index to prevent case-insensitive filesystem handling from losing it; no commit was created.
