# Preparing a OneClick release

The repository contains a reproducible release-preparation workflow. It does not publish a GitHub Release or update a Homebrew tap. No GitHub repository, GitHub account, tap repository, or final download URL has been selected yet. This repository also has no verified, usable Developer ID Application identity at the time of writing, so a public release has not been produced.

## Required Apple configuration

Install a `Developer ID Application` certificate and private key in the signing keychain. Record its 10-character Apple Developer Team ID and the full identity name shown by:

```bash
security find-identity -v -p codesigning
```

Store App Store Connect notarization credentials in a named Keychain profile. For example, one supported `notarytool` setup is:

```bash
xcrun notarytool store-credentials oneclick-release \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD
```

Do not add the Apple ID, app-specific password, private key, or exported certificate to the repository. The release script receives only the Keychain profile name.

## Build, sign, and notarize

Run the script with a plain `MAJOR.MINOR.PATCH` version and all three required environment variables:

```bash
ONECLICK_TEAM_ID=AB12CD34EF \
ONECLICK_SIGNING_IDENTITY='Developer ID Application: Example Developer (AB12CD34EF)' \
ONECLICK_NOTARY_PROFILE=oneclick-release \
./script/release.sh 1.2.3
```

The script rejects missing or unsafe configuration before starting Xcode. It builds the `OneClick` scheme into `.build/ReleaseDerivedData` with these release overrides:

- `ARCHS=arm64` and `ONLY_ACTIVE_ARCH=NO`
- `DEVELOPMENT_TEAM=<Team ID>`
- `CODE_SIGN_IDENTITY=<Developer ID Application identity>`
- `ONECLICK_APP_GROUP=<Team ID>.local.oneclick.shared`
- `MARKETING_VERSION=<release version>`

Xcode signs the app and embedded Finder extension with their configured entitlements and Hardened Runtime settings. The script then verifies that both Mach-O executables contain only `arm64`, checks the app and extension version metadata, runs strict nested signature verification, creates a temporary ZIP for `notarytool`, waits for notarization, staples and validates the app, and asks Gatekeeper to assess it. Only after those checks does it create `dist/OneClick-<version>.zip` and print its SHA-256.

`release.sh` submits to Apple's notarization service, but it does not upload to GitHub or modify a tap. A successful local run is release preparation; publication still requires a chosen GitHub repository and tap plus a deliberate upload/update step.

## Generate the Cask

After uploading the exact final ZIP to a stable HTTPS GitHub Release URL, generate the Cask from that same local archive:

```bash
./script/generate_cask.sh \
  1.2.3 \
  https://github.com/OWNER/REPOSITORY/releases/download/v1.2.3/OneClick-1.2.3.zip \
  https://github.com/OWNER/REPOSITORY \
  dist/OneClick-1.2.3.zip
```

The generated Cask is written to standard output. It uses the measured archive SHA-256, installs `OneClick.app`, requires Apple Silicon, and requires macOS Tahoe or newer. The generator accepts only plain release versions and conservative HTTPS URLs; it rejects missing archives and values that could become Ruby interpolation or quoting syntax.

To update a tap file without truncating an existing Cask when validation fails, write to a temporary file first, check it, and then move it into the tap:

```bash
temporary_cask="$(mktemp)"
./script/generate_cask.sh \
  1.2.3 \
  https://github.com/OWNER/REPOSITORY/releases/download/v1.2.3/OneClick-1.2.3.zip \
  https://github.com/OWNER/REPOSITORY \
  dist/OneClick-1.2.3.zip > "$temporary_cask" \
  && ruby -c "$temporary_cask"
```

Move the checked file to `Casks/oneclick.rb` only after the repository and tap locations are known. Before announcing a release, download the published asset independently, compare its SHA-256, and test Cask install, upgrade, and uninstall on an Apple Silicon Mac running macOS 26 or newer.

## Script tests

The release-script tests use temporary fake Xcode, signing, and notarization commands. They exercise validation, argument boundaries, operation ordering, architecture rejection, final archive creation, generated SHA-256 values, and generated Ruby syntax without contacting Apple or a release host:

```bash
tests/release-scripts/run_tests.sh
```

These tests prove the orchestration and Cask generation behavior. A real release still requires a valid Developer ID identity, a working Keychain notarization profile, successful Apple notarization, and actual GitHub/tap values.
