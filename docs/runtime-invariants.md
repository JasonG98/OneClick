# Runtime invariants

Use the relevant section when changing the settings app, Finder extension, or
shared logic. These constraints preserve existing behavior; changing one calls
for an explicit design decision and verification of the affected boundary.
See [testing.md](testing.md) for checks and [verification.md](verification.md)
for behavior actually observed on a desktop.

## Processes and permissions

- **The extension does the work.** Open/copy actions complete inside the Finder
  Sync process. There is no background agent or login item. The settings app
  exits when its last window closes
  (`applicationShouldTerminateAfterLastWindowClosed` returns `true`); the
  extension cannot depend on a live app process. It opens settings by relaunching
  the app by bundle identifier.
- **Keep the extension's read-only temporary exception.** Finder supplies
  selected URLs without sandbox access (rdar://42874694). Removing the exception
  in `config/FinderExtension.entitlements` leaves menus and path copying working
  but prevents handing files to applications. Removing it would require moving
  open actions back into the app and changing the no-background-process design.
  The exception belongs only to the extension; the app is unsandboxed.
- **Enabled and running are separate facts.** Replacing the loaded extension
  bundle kills its process; Finder does not automatically reload it even while
  System Settings still shows it enabled. `script/build_and_run.sh` re-registers
  and relaunches it after each build. Preserve both this recovery and the status
  card's distinction between the switch and process liveness.

## Shared storage and validation

- Both processes use `~/Library/Application Support/OneClick/`, resolved from
  `getpwuid_r`, never sandbox `HOME` or Foundation's default home. The extension's
  home-relative read-write exception must match that directory, including its
  final slash. Runtime code must not resolve or scan App Groups. Legacy settings
  migration is an explicit user action; see [releasing.md](releasing.md#旧版配置迁移).
- `SharedDirectory` uses a directory lock for first-run initialization and
  writes `.oneclick-owner.plist` with `CFBundleIdentifier=local.oneclick.app`.
  It refuses symlink directories, foreign markers, and nonempty unmarked
  directories. Uninstall preserves unclaimed paths and checks this marker;
  historical Group Containers are left untouched. This prevents
  accidental deletion, not tampering by another process of the same user.
- Treat `settings.json` and `last-error.txt` as untrusted input: any process of
  the same user can write them. Validate settings before use. Bound error text
  in bytes when reading and in characters before display, including malformed
  encoding; neither length nor encoding can be assumed.
- Store the application path that was checked: importing canonicalizes with
  `standardizedFileURL` before reading the bundle. `SettingsRepository.validate`
  rejects `..` path components but remains a pure check on both load and save.
  Do not require canonical URL equality: `hasDirectoryPath` affects equality,
  and Codable can add a trailing slash, making valid saved settings fail it.

## Menus and targets

- Menu construction registers a snapshot of selection and target in a bounded
  action registry. Clicking looks it up by tag; do not substitute mutable current
  state for the recorded selection or target.
- Clipboard text is one path per line. `SelectionContext.clipboardText()` refuses
  paths containing line breaks because escaping would be ambiguous to arbitrary
  paste targets. `pathText` stays the raw join for snapshots and comparisons.
  Opening uses URLs and still accepts filenames containing line breaks.
- `ApplicationResolver` opens only the stored application path. Do not fall back
  to a bundle-identifier lookup: LaunchServices registration order could select
  a different bundle claiming that identifier. Moving or renaming an imported
  app makes its menu item disappear until reimported. Terminal is the exception:
  `.terminal` targets store no path and resolve from the fixed system path.

### Application aliases

The Finder menu uses `OpenTarget.menuName`, resolved from `ApplicationAlias` with
the app's own display name as fallback. `name` remains the identity shown in
settings, row switch accessibility labels, and `PlatformError.applicationUnavailable`.

Add an alias as one entry in `ApplicationAlias.entries`. It must be strictly
shorter than the app's own name and belong to an app that opens folders;
application menu items appear only for directory selections. Verify the bundle
identifier from an installed app's Info.plist using
`/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier'`, or a distribution manifest
such as a Homebrew Cask's `uninstall quit:` / `zap` paths. Omit unverified entries.

Aliases are derived when building the menu, never stored in `settings.json`.
Adding one needs no schema change, migration, or version bump. Tests cover the
shorter-name rule, identity/menu wording, and unchanged serialization.
