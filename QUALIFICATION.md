# Qualification and release handoff

Run against disposable identities, approved test trust, isolated receiver storage, and an explicitly configured build. Never reuse a live wallet or broaden production grants for a test.

## Source checks

The evidence manifest records commands, versions, source/artifact hashes, and log hashes. `Dependencies.json` now pins the published Wallet commit; release evidence records exact source and packaged artifact hashes. Older evidence using candidate file digests does not qualify a newer package.

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

## Generic Work server setup — build 9

The app accepts an administrator-provided HTTPS server origin and public issuer pin through a reviewed connection file or manual entry. In build 9, Tailscale was optional connection guidance; build 10 replaces that behavior with the enforced embedded route below. No Work server configuration is bundled, and unknown profile fields or credentials are rejected. A connection check carries no identity and cannot authorize reads. Saving/removing settings clears applicable local read authority so a new selection requires fresh approval. Existing bundled previews require explicit setup after upgrading.

Test empty setup, ordinary HTTPS and Tailscale choices, malformed/oversized/mismatched profiles, local persistence, stale replacements and removal. Verify that an unreachable server does not change saved settings, and that editing a URL cannot retain another receiver's authority. Inspect the final package for deployment configuration before distribution. On a real phone, separately qualify network setup, membership approval, exact read-scope approval and first read. Record installation-specific details only in ignored local evidence, never public source or release documents.

## Embedded Tailscale — build 10

- Source: 37 Swift tests pass, including 11 new private-network lifecycle/transport tests and the existing recovery/custody regressions.
- Native dependency: pinned TailscaleKit iPhone and arm64 Simulator frameworks built; source patch and exact framework hashes recorded locally.
- Simulator: real embedded node reached the official Tailscale sign-in page without the separate Tailscale app. Cancellation returned to the preserved setup. No account or tailnet was authorized during this check.
- Signed iPhone build: build 10 verified and installed in place without removing Wallet storage. The user’s real tailnet sign-in/read result remains outstanding.
- Pending physical-device gate: sign in, approve the app's node on the selected network, check server reachability, approve exact read scope, read a page, then background/lock/unlock and repeat. Include denial, expired/revoked device access, offline/cellular changes, largest Dynamic Type and VoiceOver.

The minimum app OS is now iOS 18.1, matching the pinned framework. No system-wide VPN permission is requested. [PRIVATE-NETWORK.md](PRIVATE-NETWORK.md) records module and authority boundaries.

## Connection setup clarity — build 11

Connection-file import now appears first, the empty address field has an instructional placeholder, and manual verification settings remain collapsed. The sign-in status and action use distinct wording. No transport, trust, or credential behavior changed.

- The isolated Simulator setup app built and launched; the direct/private selector, import placement, address prompt, and collapsed verification controls were visually checked.
- The complete signed iPhone app built and passed signature verification. A package scan found no local Work deployment values or bundled Work configuration. Build 11 has not yet been installed on the phone.
- The user confirmed that build 10 opens the sign-in page on the physical phone. Network enrollment, server reachability, and an approved read remain unverified.
