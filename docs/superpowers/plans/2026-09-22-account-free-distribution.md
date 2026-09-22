# Account-free distribution implementation plan

> Execute inline with superpowers:executing-plans; use regression tests and one final independent review.

**Goal:** Build and prepare OneClick releases without an Apple account.
**Architecture:** Keep app/extension boundaries; replace App Group with a narrow shared directory exception.
**Tech stack:** Swift 6, Xcode, Bash 3.2, Python standard library, GitHub Actions, Homebrew Cask.
**Spec:** `docs/superpowers/specs/2026-09-22-account-free-distribution.md`.

## Constraints and decisions

- arm64, macOS 26+, no notarization or credentials; test entrypoint remains `script/check.sh`.
- User delegated remaining choices; execute without further design approval gates.
- Work on `codex/account-free-distribution` in the clean existing checkout; no concurrent implementation.
- Preserve ignored legacy local signing configuration and privacy hygiene checks.
- No public publishing, external tap mutation, or real data deletion during implementation.

## Tasks

1. Shared directory and signing defaults
   - [x] Replace AppGroupAccessTests with temporary-home shared directory behavior tests.
   - [x] Add SharedDirectory, switch SharedEnvironment, update entitlements/plists/generator/build script.
   - [x] Generate project twice and compare; run shared-directory tests and signed Debug build.
2. Release pipeline and Homebrew
   - [x] Replace notarization mocks with DMG assembly/failure tests; verify cask hash and metadata.
   - [x] Implement ad hoc release.sh with temporary staging, Applications link, hdiutil verification.
   - [x] Generate .dmg cask, add reusable check workflow and tag-triggered draft release workflow.
   - [x] Exercise script tests and build a real DMG; inspect mounted contents and signatures.
3. Uninstall and documentation
   - [x] Add temporary-home tests for new data cleanup, missing/foreign marker and symlink preservation.
   - [x] Extend uninstall while preserving legacy container and bundle ownership checks.
   - [x] Align README, CONTRIBUTING, AGENTS, testing, releasing and dated implementation log.
4. Verification and review
   - [x] Run `./script/check.sh --build --disable-sandbox`.
   - [x] Attempt sandbox/Finder runtime checks; record exact evidence and remaining gaps in verification.md.
   - [x] Independent review of shared home resolution, rights, delete boundaries, publication and archive failures.

## Review focus

Sandbox home redirection; first-run/racing directory creation; foreign/symlink shared paths;
failed DMG creation preserving prior artifact; tag/ref mismatch and published-release overwrite.

## Execution record

Baseline and per-task outcomes are appended here as work proceeds.

- Baseline: 43 script tests passed before changes.
- Final: 96 Swift tests; 51 script tests after regression additions; unsigned arm64 build passed.
- Ad hoc Debug app/extension launch, signed Release DMG and sandbox positive/negative probes passed.
- Ruling: GUI/clean-account and remote distribution checks remain explicitly unverified; desktop capture failed with -3811.
- Ruling: first-run directory locking and marker refuse accidental foreign deletion, not malicious same-user races.
- Final review: independent reviewer found one inherited --verify false-success; reproduced RED and fixed GREEN.
- Runtime follow-up: delayed plugin deregistration could defeat one-shot reload; bounded re-registration added with RED/GREEN regression, and final real --verify returned 0 with both processes alive.
- Deferred evidence: clean-account TCC/Gatekeeper GUI, full Finder interaction, live GitHub Actions/tap; no hidden approval gate or remote publication performed.
