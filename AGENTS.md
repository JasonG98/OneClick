# Project conventions

OneClick is a macOS Finder right-click utility: a SwiftUI app plus an embedded
Finder Sync extension. This file is the working brief for agents and
contributors. The user-facing description lives in [README.md](README.md).

## Directory layout

- Ordinary repository directories use lowercase names; separate multiple words with hyphens.
- Application sources live in `src/app/`, Finder extension sources in `src/finder-extension/`, and shared sources in `src/shared/`.
- Keep application entry files directly in `src/app/`; use `stores/` and `views/` for their respective responsibilities.
- Shared platform-independent logic lives in `src/shared/core/`; macOS integration lives in `src/shared/platform/`.
- Tests live in `tests/core/`, `tests/behavior/`, and `tests/release-scripts/`.
- Configuration lives in `config/`, documentation in `docs/`, and scripts in `script/`.
- `script/lib.sh` is sourced, never executed: it holds the helpers shared by more than one script (repository root, failure reporting, environment and version validation). Add a helper there when a second script needs it, not in anticipation.
- Artwork that is not compiled by Xcode lives in `assets/`; only `src/app/resources/` is inside the app's asset catalog.
- Keep Swift filenames aligned with their primary type. Preserve tool-defined names such as `Package.swift`, `README.md`, `AGENTS.md`, `OneClick.xcodeproj`, and hidden tool directories. Generated build artifacts and Xcode-managed internal directories are exempt from the lowercase rule.

## Skills and plugins

- Adapt skill/plugin directory examples to this project layout. Do not create root `App/`, `Views/`, `Sources/`, `Tests/`, `Docs/`, `Scripts/`, or script directories under source directories.
- Superpowers documents belong in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- The macOS build/run entrypoint remains `script/build_and_run.sh`; the Codex Run action uses that path.
- `script/uninstall.sh` removes the app and its data from a Mac, and is the only script that deletes things outside the repository. It reports by default and needs `--apply` to act; keep that default, and keep the ownership checks (container metadata, bundle identifier) rather than matching paths by name.
- Preserve the existing app, extension, and shared-code boundaries; create additional directories only when needed.

## Documentation map

| Document | What belongs there |
| --- | --- |
| `README.md` | User-facing: what the app does, how to install and use it, FAQ |
| `AGENTS.md` (this file) | Conventions, invariants, and the traps that only show up when changing code |
| `docs/implementation-log.md` | Dated entry per non-trivial change: what was tried, what failed, how it was verified |
| `docs/testing.md` | Test layers and how to run them |
| `docs/verification.md` | Behaviour actually confirmed on a real desktop |
| `docs/releasing.md` | Signing, notarizing, packaging, Cask |

## Build and verification

- Generate the committed Xcode project with `python3 script/generate_project.py` after changing project paths or settings. Update the generator rather than only editing the generated project; its output is deterministic, so `git diff OneClick.xcodeproj` must stay empty after a rerun.
- `src/app`, `src/shared`, and `src/finder-extension` are filesystem-synchronized groups: adding or deleting a Swift file does **not** require touching the project file.
- SwiftPM uses explicit paths in `Package.swift`; keep them synchronized with source moves.
- Run `./script/check.sh --build` for Swift tests, release-script tests, the icon parity check, shell syntax checks, and an unsigned app/extension build without launching the app. In a nested sandbox, append `--disable-sandbox` for SwiftPM.
- `./script/check.sh` is the only test entrypoint. Anything it does not recognise is forwarded to `swift test`, so SwiftPM flags work directly (`./script/check.sh --filter FinderMenuTests`). `--icons` adds the `.icns` round trip.
- Keep local signing configuration in ignored `config/Local.xcconfig`.
- Write the team id as `<Team ID>` in documentation, comments and fixtures. The real value belongs only in `config/Local.xcconfig`, which stays ignored and untracked; `tests/release-scripts/test_repository_hygiene.py` enforces both halves and scans the working tree for the value itself.

## Tests

- Three layers: `tests/core/` (selection semantics, settings model, migration), `tests/behavior/` (real `NSMenu` construction, open routing, pre-flight access checks), `tests/release-scripts/` (distribution scripts and the icon renderer).
- Tests substitute system calls, use isolated temporary directories, and must **not** launch target applications, write the system clipboard, or touch the real App Group.
- Run one suite while developing: `./script/check.sh --filter FinderMenuTests`.

## Icon pipeline

- `assets/icon.svg` is the single piece of artwork and is shared: the README embeds it (as `assets/icon.png`) and the app icon is rasterized from it. Edit the SVG, never the outputs.
- `script/generate_icon.py` is the only icon script, and parses and rasterizes that SVG with numpy only. It writes the 16–1024 PNG ladder in `src/app/resources/Assets.xcassets/AppIcon.appiconset`, the `Contents.json` that tells actool which rungs to compile, and the README's `assets/icon.png`. `--check` re-renders and compares instead of writing; `--icns PATH` additionally assembles a verified standalone `.icns`. A plain run writes the committed outputs and nothing else.
- Nothing in the build consumes a hand-built `.icns`: the app's `Contents/Resources/AppIcon.icns` is produced by actool from the PNG ladder, because the target sets `ASSETCATALOG_COMPILER_APPICON_NAME`. The wrapper script that used to build one beside the build product was removed for that reason; `--icns` keeps the verification it performed.
- The renderer implements **only** the subset the artwork uses (`<rect rx>`, `<path>` `M L H V A Z`, `<g transform="translate()">`, solid and vertical multi-stop gradient fills with `stop-opacity`, and `stroke`) and raises on anything else. That is deliberate: it must never silently draw the icon wrong. Extend it when the artwork needs a new construct.
- Strokes are rasterized as "distance from the centreline ≤ half the stroke width" rather than converted to outlines: a stroked shape's outline self-intersects at inner corners, and no fill rule recovers the band. Elements are composited premultiplied source-over, so a translucent paint washes the colour without thinning the icon's own alpha.
- Both rasterizer kernels walk one edge or segment at a time **on purpose**. Batching them into a `(edges, rows, columns)` numpy reduction was implemented and measured slower — the plate ring alone has 797 vertices, so a batch materializes a dense array whose traffic costs more than the Python it removes (6.0s against 3.6s at 1024). Do not re-apply that optimization without measuring it.
- Verify icon changes by regenerating and comparing the outputs, not by editing them: two runs must produce identical bytes, and `./script/check.sh` fails when the committed outputs no longer match the SVG.

## Runtime invariants

These are the constraints that make the app work the way it does. Changing code around them needs a deliberate decision, not a casual edit.

- **The extension does the work; the app does not stay resident.** Every open/copy action completes inside the Finder Sync process. That is why there is no background agent, no login item, and why the app only runs while its settings window is open — closing that window quits it (`applicationShouldTerminateAfterLastWindowClosed` returns `true`), so the extension must never assume a live app process. The extension relaunches the app by bundle id when settings are requested.
- **`config/FinderExtension.entitlements` must keep its read-only temporary exception.** Finder hands the extension selected URLs *without* sandbox access (Apple issue rdar://42874694). Without the exception the menu still appears and paths still copy, but handing a file to any application fails. Removing it means moving the open action back into the app — and giving up the no-background-process design. The exception is granted to the extension only; the app itself is unsandboxed.
- **Finder loads a Finder Sync extension once.** Replacing the running extension bundle on disk kills the process and Finder never starts it again, while System Settings still shows the switch as on. `script/build_and_run.sh` re-registers and relaunches the extension after every build; the settings status card treats "enabled" and "running" as two separate facts. Do not regress either one.
- **The shared App Group needs a real team signature.** Ad hoc signing cannot authorize it and causes repeated "access other app data" prompts, so the build script refuses to run the integrated app without a team, and the extension verifies the signing team before touching the shared container.
- **Menus are snapshot-based.** Menu construction registers "selection + target" in a bounded action registry and looks it up by tag when the item is clicked; do not move mutable state between those two moments.
- **The clipboard payload is one path per line, and a path containing a line break is refused rather than escaped.** The newline *is* the separator, so an escaped path would be indistinguishable from two paths — and the paste target is an arbitrary application, not this one. `SelectionContext.clipboardText()` owns that rule; `pathText` stays the raw join for menu snapshots and comparisons. Only copying is restricted: `open` passes URLs and never text, so a file whose name contains a line break still opens.
- **Only the path the user chose is opened.** `ApplicationResolver` never falls back to a lookup by bundle identifier: that hands the choice to LaunchServices registration order, where another bundle claiming the same identifier takes the action over while the menu still shows the name the user picked. Terminal is the one exception and resolves from its fixed system path, because `.terminal` targets are required to carry no stored path. The accepted cost is that moving or renaming an imported application makes its menu item disappear until the user imports it again.
- **Everything in the App Group container is writable by any process running as this user.** `settings.json` and `last-error.txt` are inputs, not trusted state: validate before acting on them, and bound anything on its way to the UI. Error text is capped in characters before it is shown and in bytes when it is read, because neither its length nor its encoding is ours to assume.
- **`applicationURL` is stored canonicalized, and its validation stays a pure check.** Importing an application canonicalizes with `standardizedFileURL` before reading the bundle, so the path that gets stored is the one that was checked. `SettingsRepository.validate` rejects `..` components but must never rewrite data — it runs on load as well as on save. Do not tighten it into requiring canonical equality: `URL` equality is sensitive to `hasDirectoryPath`, a Codable round trip adds a trailing slash, and demanding it would make already-saved good configuration unreadable.

## Menu wording and application aliases

- The Finder menu prints `OpenTarget.menuName`, never `name`. `menuName` resolves through `ApplicationAlias` (bundle id → short name) and falls back to the application's own display name. `name` remains the identity: the settings window, the accessibility label on each row's switch, and `PlatformError.applicationUnavailable` all use it, so the app the user sees there is the app they find in `/Applications`.
- Adding an alias is **one entry in `ApplicationAlias.entries`** and nothing else. The short name must be strictly shorter than the app's own name — a test asserts it, because an "alias" that is not shorter is just a second long name. Read the bundle id from a real source instead of recalling it: `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier'` on the installed app, or a distribution manifest (a Homebrew Cask's `uninstall quit:` / `zap` paths) when the app is not installed here. Drop the entry if neither confirms it.
- Aliases are derived when the menu is built and are deliberately **not** stored in `settings.json`: no schema change, no migration, no version bump, and a new entry takes effect without touching anyone's configuration. A per-user override, if it is ever wanted, is one more field consulted inside `menuName` ahead of the table.
- Only applications that can open a *folder* belong in the table. Application items appear for directory selections only, so browsers and chat apps never reach these titles.

## Gotchas

- A stale LaunchServices registration for the same bundle id makes a rebuild show the previous icon: the icon resolves through the registration, and an older copy under `.build/` can win it. `script/build_and_run.sh` retires those registrations and touches the bundle so Icon Services drops its cached entry.
- Build warnings about `swift-plugin-server ... sandbox_apply` (macro expansion failing) are an environment/sandbox limitation, not a code error.
