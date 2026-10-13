# Qualification and release handoff

Run against disposable identities, approved test trust, isolated receiver storage, and an explicitly configured build. Never reuse a live wallet or broaden production grants for a test.

## Source checks

The evidence manifest records commands, versions, source/artifact hashes, and log hashes. Its repository revisions are base revisions plus candidate file digests; they are not claims that uncommitted work is published.

- Wallet: `cargo test --workspace --locked --offline`, `cargo fmt --all -- --check`, `npm test`, `npm run typecheck`. Public v3/v4 fixtures exercise preserved signing transcripts; portable validation rejects wrong owners, signatures, descriptors, authority injection, and unknown fields.
- Native: `scripts/build-core.sh`, `swift test`, Xcode Simulator build. Swift tests exercise actual Rust custody, durable storage, stale/cancelled previews, HTTPS/redirect handling, bounded responses and unsupported grants.
- Web: `pnpm test`, `pnpm typecheck`, `pnpm lint`, `pnpm build`, `pnpm verify:contracts`, `pnpm verify:wallet-core`, `pnpm browser:recovery`. The recovery browser suite uses a new browser context and real worker/WASM/IndexedDB. Use `CASTALIA_BROWSER_EXECUTABLE_PATH` for an installed Chrome, or Playwright's installed Chromium.
- Devgraph: auth/delegated-read/native-read suites. Set `CASTALIA_RECOVERY_TEST_DRIVER` to Wallet's built `target/debug/examples/recovery_contract_driver` to require the actual Rust-to-Python test instead of its explicit skip. Build that test helper with `cargo build --locked --offline -p castalia-wallet-core --example recovery_contract_driver`.

Browser source tests are not physical Safari tests. An iOS library build is not a signed device build. A read-enrollment fixture pass is not the separate Devgraph → Wallet → secS mutation-signing release gate.

## QR and USB transfer — Build 3

`swift test` includes independent framing vectors, generated Core Image QR decoding with Apple Vision, malformed/mixed/duplicate/out-of-order frames, file limits and source preservation, and actual reconstruction through Rust recovery. Build the native Mac companion with `sh scripts/build-transfer-app.sh`. iOS Simulator and signed device builds must also pass. These tests do not qualify camera capture of a laptop screen or a physical cable copy.

On a disposable identity, verify single and animated QR capture across brightness/distance, camera denial and retry, cancellation/backgrounding without partial import, and explicit password/review/commit. Exercise Finder/Apple Devices file sharing, refresh, source preservation, wrong files, and interrupted file selection. Test existing-wallet backup verification and data import without identity replacement. Record exact final artifact hashes. See [the transfer contract and instructions](TRANSFER.md). Physical optical/cable testing and the Mac companion interactive check are currently outstanding.

## Physical iPhone gate — outstanding

Build 6 onboarding uses two independent paths. For creation, test welcome → local password → save encrypted recovery file → select the saved file → verify → completion. For import, test welcome → immediate scanner → backup password → new local password → validated review → confirmed durable import → completion. Also cancel the scanner, use secondary USB/Files import, add/remove optional data, go back from each step, and background/lock at each boundary. Selecting a backup or advancing to the local-password screen does not claim cryptographic validation; only the prepared review does. New credentials must be entered and submitted by the person testing. Current Simulator navigation evidence is partial and does not substitute for completing these paths on the phone.

Record device, iOS version, Xcode version, signing identity/team reference (no private material), app build hash, core source/library hashes, receiver revision, and test configuration digest. Preserve receipts/manifests with bearer values removed.

1. On a clean disposable installation create, save to Files, select the saved recovery file and verify it. Attempt membership before verification and prove it is denied.
2. Approve the test issuer and join; separately approve displayed read scopes. Read a real scoped page and item through HTTPS. Verify pagination, forbidden resources, no write route, revocation, expiry and renewal without permission expansion.
3. Lock/background at password entry, file picker, preview, network wait and save. Resume by unlocking. Cancel at each stage and compare the durable snapshot. Exercise protected-data lock, navigation interruption, storage failure, and a response lost after enrollment.
4. Export data and recover on a clean disposable installation. Check Ed25519 and ML-DSA-65 identities and descriptors. Import both v3 and v4 proof files, reject mismatches/tampering, review replacements, preserve omitted proofs and disclosure settings. Membership is inactive and Work access absent after restore.
5. Exchange files with the exact Web/WASM build. Test a valid historical short-password file and legacy key input, then encrypted-backup migration. The original files remain unchanged.
6. Use VoiceOver, largest Dynamic Type, reduced motion, dark appearance, small screen and keyboard. Confirm clear focus order, 44-point controls, announcements, no truncated consent and no sensitive app-switcher snapshot.
7. Inspect traffic/storage/logs: no file payloads, passwords, recovery roots or portable bearer values are transmitted or logged. Only explicitly approved membership/read requests leave the app.

Use an isolated test identity for destructive clean-install steps; do not erase a user's wallet. Exact final packaged artifacts must pass after any custody/persistence changes.

## Simplicity gate — outstanding

Five people unfamiliar with implementation try create/check, restore, connect and read. At least four complete each assigned journey without coaching. Everyone must understand that access is read-only and data alone cannot restore signing identity. Record confusion, changes and retests. A technical source review or prototype review is not this usability evidence.

## Live activation — excluded

No production trust, memberships, credentials, grants, migrations, data, server routing or deployment are changed. A developer signing team, physical device, approved distributor configuration, and separate rollout decision are still required.
