# Zenith iOS implementation state

Updated October 13, 2026. Published native preview source. Generic server setup replaces bundled Work deployment settings. Physical device enrollment/read and broader qualification remain separate from source checks. This is not an App Store release.

## Current implementation

- Separate SwiftUI Work and Wallet destinations. Onboarding forks into Create a wallet and Scan to import, with complete separate navigation flows and shared view primitives.
- The shared Rust Wallet core owns encrypted custody, recovery/Castaway validation, backup verification, membership, and holder-proof signing. Swift uses the opaque native ABI and durable revision-checked SQLite storage.
- Offline QR transfer carries the encrypted file itself; the Mac companion and USB/Files routes feed the same validated import flow. Existing wallets cannot be replaced.
- `Dependencies.json` pins Wallet `f654017`. The builder checks the revision and relevant source cleanliness. Work server address and issuer pins are supplied and approved locally. No Work deployment configuration is bundled.
- Devgraph issues a signed read credential under explicit operator policy. secS verifies issuer signature, holder proof, expiry, exact operation, and current registry status. Devgraph consumes replay nonces and applies resource/Arena restrictions before pagination.
- Read permissions cover the five concrete Work types: Proposal, Initiative, Project, Issue, and Task. Base Todo and canonical progress are not exposed by the existing delegated projection; absent progress is shown as “Progress not recorded.”

## Evidence

| Check | Result |
| --- | --- |
| Swift | Custody, QR, persistence, transport, anonymous connection checks and generic server settings covered |
| Device package | Signed development builds; exact artifact/install results remain in local evidence |
| Connection UI | Generic address entry, optional Tailscale guidance, independent issuer settings and explicit local confirmation |
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
