# Zenith iOS implementation state

Updated October 13, 2026. Published native preview source. Generic server setup replaces bundled Work deployment settings. Physical device enrollment/read and broader qualification remain separate from source checks. This is not an App Store release.

## Current implementation

- Separate SwiftUI Work and Wallet destinations. Onboarding forks into Create a wallet and Scan to import, with complete separate navigation flows and shared view primitives.
- The shared Rust Wallet core owns encrypted custody, recovery/Castaway validation, backup verification, membership, and holder-proof signing. Swift uses the opaque native ABI and durable revision-checked SQLite storage.
- Offline QR transfer carries the encrypted file itself; the Mac companion and USB/Files routes feed the same validated import flow. Existing wallets cannot be replaced.
- `Dependencies.json` pins Wallet `f654017`. The builder checks the revision and relevant source cleanliness. Work server address and issuer pins are supplied and approved locally. No Work deployment configuration is bundled.
- Devgraph issues a signed read credential under explicit operator policy. secS verifies issuer signature, holder proof, expiry, exact operation, and current registry status. Devgraph consumes replay nonces and applies resource/Arena restrictions before pagination.
- Legacy connections retain the five-type reader. The October 17 adapter also accepts explicitly versioned monitor scopes for Todo, canonical progress and permitted relationships; missing progress remains “Progress not recorded.”

## Evidence

| Check | Result |
| --- | --- |
| Swift | Custody, QR, persistence, transport, anonymous connection checks and generic server settings covered |
| Device package | Signed development builds; exact artifact/install results remain in local evidence |
| Connection UI | On-device profile discovery, guided embedded Tailscale sign-in, read-scope review and separate manual setup |
| Shared Wallet | Rust/native/WASM and JavaScript/typecheck source suites passed |
| secS | 813 workspace tests passed, 1 ignored; separate shared read contract and parity checks passed |
| Devgraph | Earlier full run: 2,642 passed, 5 skipped; exact release read integration: 20 passed; runtime/audit checks: 31 passed |
| Real phone read | Pending the member’s explicit approval and first read |

Local manifests record full revisions, artifact hashes, configuration digests and test logs under ignored `verification/` and `Artifacts/` directories. Those files are not distributed as public evidence or source dependencies. Remote PR checks are tracked on the coordinated repositories.

## Outstanding qualification

Complete the physical-device negative/recovery/accessibility matrix in [QUALIFICATION.md](QUALIFICATION.md), including cancellation, background locking, interrupted storage/network, stale trust, expiry and revocation. Use disposable identities for destructive tests. The user has demonstrated a successful recovery import on the real phone, but that does not qualify every recovery path or failure case.

The five-person simplicity study, independent custody review and App Store/TestFlight distribution remain outstanding. The separate installed browser/terminal mutation-signing gate is unchanged by read-only activation.

## Delivery boundaries

The new app is published at `ZenithResearch/zenith-ios`. Companion source is coordinated through Wallet #32, public Devgraph #10 and secS #298. The private Devgraph archive is not a dependency. Server setup requires no graph migration, Work mutation, wallet replacement or owner-credential forwarding. Unrelated Web, Wallet preview, and Devgraph maintenance work remains preserved in its own checkout.

## Embedded private connection — build 10

Work connection now offers Direct or Private via Tailscale. The private route uses the official pinned TailscaleKit/libtailscale framework inside Zenith, with explicit sign-in and no direct fallback. Public server drafts survive wallet locking, and Connection remains available from the Work toolbar. Networking does not modify Rust custody, issuer trust, read grants or receiver policy. Native startup/sign-in cancellation was exercised in Simulator; actual phone enrollment and a private holder-bound read remain user-dependent qualification steps.

## Guided connection and biometric unlock — build 12

Validated public profiles in Zenith’s Documents folder appear as a Connect button. In-app instructions cover missing files, network login, and separate read approval. Optional Face ID/Touch ID saves the verified wallet password in a device-only, current-biometric-set Keychain item. The shared Rust custody and signing contracts remain unchanged; Swift adds lifecycle and identity checks around unlocking. Password AutoFill and ordinary password unlock remain available.

43 Swift tests pass, including six added discovery/biometric-coordination tests. The real Keychain adapter builds in the signed iPhone app; synthetic storage tests are not qualification of physical Face ID. First device enrollment/unlock, biometric changes/lockout, and the end-to-end private read remain outstanding until exercised on-device.

## Monitor read compatibility — October 17, 2026

PR #1 is merged. The follow-up native reader accepts the explicitly versioned v2 and v3 scope/result pairs. Modern connections use the monitor read endpoint for Todos, canonical progress, revision-bound pages, detail reads and permitted relationships. Older saved five-type connections retain their original transport. The consent screen shows operations and relationship types, in addition to resource/Arena scope and expiry.

Wallet source pin, native ABI, recovery files, encrypted snapshot schema and issuer trust remain unchanged. New tests cross the actual native Rust approval/storage/signing boundary with disposable issuers and a stub HTTP receiver; Python-generated fixtures pin the real public Devgraph response shapes. No live receiver, credential, grant or phone installation changed. Physical-device acceptance and the native request/status flow for the newer shared approval inbox remain outstanding. See READ-COMPATIBILITY.md for exact coverage and limits.

## Hermes Chat — build 15, October 17, 2026

Adds a native Chat tab, a generic HTTPS gateway connection importer, device-only Keychain authorization, normal Hermes Sessions API calls and recovery of server history after unlock. Private routing reuses the embedded Tailscale session; an interrupted send is never retried automatically. Work/custody/recovery contracts remain unchanged.

The actual Swift client passed an authenticated chat and history reload through the dedicated tailnet HTTPS gateway. The combined suite ran 57 tests with one optional LAN probe skipped and no failures, including the explicit live Swift chat test. Repeated conversation creation no longer supplies a conflicting fixed title. Simulator compilation and a signed iPhone build passed. Phone installation and physical connection/import/background/accessibility checks are recorded separately; no phone result is inferred from the Mac test. Streaming, voice, attachments and tool-approval screens are deferred. See HERMES-CHAT.md.
