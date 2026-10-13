# Zenith iOS implementation checkpoint

Updated October 12, 2026. **Source candidate implemented; not release qualified.** Disk-space recovery is complete.

## Delivered source

- Native SwiftUI Zenith app with two destinations: Work and Castalia Wallet. Simple creation, unlock, recovery, membership and read-access journeys; adaptive appearance and scrolling welcome screen. The existing iOS app and phone website are unchanged.
- The same Rust recovery/portable-data core is built for iOS, Simulator, macOS tests and Web/WASM. Core and presentation crates are MIT licensed, as explicitly approved. Public Web carries a checksum-pinned source snapshot with provenance and a build-time verifier.
- Encrypted recovery and optional Castaway restore, public review/confirmation, same-identity data import/export, proof preservation, descriptor validation and separately approved trust. Legacy recovery-key input remains; raw-key output/reveal is removed from the Web journey.
- Build 3 adds offline QR transfer of the encrypted file itself, a local Mac QR companion, and USB/Finder file import. All paths feed unchanged Rust validation and confirmed restore. Small files use one QR; larger files use bounded animated frames. See [transfer instructions](TRANSFER.md).
- Save → select actual saved file → verify gates new-wallet enrollment/signing. Historical Web confirmations remain eligible without being relabeled as checked backups. Valid older short-password files still import.
- Revision-checked SQLite persistence on iOS and whole-record compare-and-swap IndexedDB transactions on Web. Staged cryptography, cancellation, lifecycle invalidation and complete-record commits prevent partial restores.
- Explicit Zenith membership and Devgraph-owned read provisioning, encrypted per-installation read credentials, exact permission disclosure, bounded pages and a native reader. Imported proofs are inactive and credentials are not portable. Unconfigured builds clearly require setup.
- Public Devgraph receiver composition with v3/v4 verification, policy/replay checks, scope ceilings, expiry/revocation, redacted errors and existing bounded Work reads. No mutation authority or local owner-key fallback.

The first delegated read projection supports the five concrete Work types. It does not claim base Todo or canonical progress absent from that legacy response; the app says “Progress not recorded.” A later versioned read-contract extension is needed for those fields.

## Verified

| Area | Recorded result |
| --- | --- |
| Shared Wallet | Rust workspace, JavaScript workspace and typechecks passed; final recovery tests **5 passed**, portable tests **3 passed**, pinned-source check passed |
| Native | XCFramework for arm64 iOS/Simulator/macOS; **15 Swift tests passed**, including real Rust recovery through QR and Apple Vision decoding of rendered QR images; final Xcode Simulator/device builds and Mac companion build passed |
| Public Web | **263 workspace tests passed**, full typecheck/lint/build, contract generation checks, source-pin checks, documentation/format gates and license policy passed |
| Web Rust/WASM | **20 Rust tests passed**; WASM built from pinned shared core |
| Recovery browser | **2 headless Chrome journeys passed**, real worker/WASM and save/select/restore, scoped axe inspection and IndexedDB competing-write/abort checks; **7 UI tests** passed after final copy adjustment |
| Public Devgraph | **371 auth/read tests passed**, including actual Rust approval to Python enrollment/guarded reader; final narrowed receiver rerun **12 passed** |
| Simulator | Final preview installed and launched on iPhone 16 / iOS 18.6; interactive QA approved and started. User created a disposable wallet; Wallet status and the recovery setup screen inspected. Save/select/check and restore are not yet verified in Simulator. |
| Physical iPhone installation | Build 3 signed, signature verified, installed and launched on paired iPhone 14 Pro Max. Profile expires October 19, 2026. Optical/cable recovery qualification remains outstanding. |

See [the source/artifact evidence manifest](verification/source-checks-2026-10-12.json). Logs and the [welcome screenshot](Artifacts/welcome-iphone16-final.png) are local ignored artifacts. Base Git revisions are accompanied by candidate file hashes; these are not published commit pins. Initial sandbox/tool-cache failures were resolved and the affected checks rerun. No failed check is counted as a pass.

The [physical iPhone preparation record](verification/iphone-preparation-2026-10-12.json) preserves the initial setup blockers. The [installation record](verification/iphone-installation-2026-10-12.json) records the later successful signing/install and the outstanding first-launch trust check. The user subsequently reported wallet setup complete in Simulator; the final backup-check state has not been independently observed.

Build 2 gives **Create a wallet** and **Import a wallet** equal visual prominence, with consistent import labels. The [UI verification record](verification/create-import-build2-2026-10-12.json) records successful device/Simulator builds, signature verification, a fresh-install Simulator screenshot, and the physical update installation. The screenshot used an isolated QA bundle to preserve the existing Simulator wallet. Core and persistence are unchanged; full physical-device recovery qualification remains outstanding.

The [Build 3 evidence record](verification/qr-usb-build3-2026-10-12.json) pins the QR/USB source and packaged artifacts. Simulator checks verified transfer choices, stable USB presentation/refresh/cancellation and camera-denial feedback. An initial sheet-presentation bug was corrected and both iOS builds rerun before the final installation. Opening the ad-hoc Mac companion was blocked by automatic approval review pending explicit launch approval; Mac interactive QA is not claimed.

The user subsequently approved opening the original Mac companion, and its initial file-choice screen was observed. Companion build 4 adds local file discovery and content-based version/legacy labels. **18 Swift tests passed**, including real Rust data-export classification, legacy recovery naming, unsupported versions, authority injection, nonrecursive discovery and source preservation; the shared iOS code still builds. Reopening this changed ad-hoc binary was separately blocked by automatic approval review pending approval. Its new catalog UI has not yet been inspected interactively. See [the catalog evidence record](verification/catalog-build4-2026-10-12.json). The installed iPhone remains build 3.

After the user's next launch approval, build 4 opened and its accessibility tree confirmed all five discovered files with correct format and legacy labels. Companion build 5 adds a saved date/time to rows and details and sorts across folders, newest first. The saved date is the file modification time, with unavailable dates last and paths breaking ties. Build and strict signature verification passed; expected order was checked against filesystem metadata. No custody, file-access, or wire-contract change was made, and no new tests were added for this display-only update. Automatic approval review requires fresh approval to open build 5, so its final UI inspection is pending. See [the saved-date evidence](verification/saved-dates-build5-2026-10-12.json).

## Remaining acceptance

Build 6 replaces the large native onboarding form with one welcome fork: **Create a wallet** or **Scan to import**. Creation has dedicated password, save-backup and check-backup pages before completion. Import opens the scanner directly, then presents the backup password, new local password and validated review/confirmation separately. Optional Castaway data has its own sheet; USB/Files remain available behind one secondary menu. Persistent field labels and adaptive dark-mode tint fix the unreadable controls reported on the phone.

The flows live in `CreateWalletFlow.swift`, `BackupWalletFlow.swift` and `ImportWalletFlow.swift`, with shared view primitives in `WalletFlowComponents.swift` and optional data in `RestoreDataAttachmentSheet.swift`. Rust custody, storage schemas and transfer contracts are unchanged. **18 Swift tests passed**, final Simulator and signed device builds passed, and strict signature verification passed. Build 6 was installed as an update on the paired iPhone, preserving its wallet. Simulator checks covered both entry choices, direct scanner presentation, camera-denial feedback, fixture selection through the USB screen, import password-step navigation, optional-data cancellation and back navigation. Light/dark creation and final dark control contrast were inspected. These checks did not create/import a wallet or complete the final save/select/verify journey; new-credential entry remains a user action. See [the Build 6 evidence record](verification/guided-onboarding-build6-2026-10-12.json).

1. Interactive Simulator QA is in progress. Creation succeeded with the user entering the disposable password privately. Recovery save/select/check, lock/unlock, restore and cancellation remain to be completed. New-password entry and submission are handed to the user as required by automatic approval review; navigation is already approved. The separate disposable Chrome tests above are automated browser checks.
2. Physical iPhone save/select/restore, actual optical QR/animated capture and Finder cable transfer, membership/read provisioning against an approved test receiver, VoiceOver, largest Dynamic Type, interruption and device-lock qualification remain outstanding.
3. The five-person simplicity study, independent custody review, reviewed commit pins and signed distribution artifacts remain outstanding. No signing team or live service configuration was introduced.
4. The separate installed Devgraph → Wallet → secS → receiver mutation-chain gate remains untouched.

[Qualification instructions](QUALIFICATION.md) distinguish these gates from source tests. [Build and configuration guidance](README.md) explains how to prepare an approved disposable test build. No live identity, credentials, grants, trust, graph data, production migration or deployment was changed.

## Working locations and preservation

- App: this greenfield directory, currently local source.
- Shared Wallet: `../worktrees/castalia-wallet/phone-request-wallet`, branch `codex/phone-request-wallet`.
- Public Web: `../worktrees/castalia-web/guided-recovery`, branch `codex/guided-recovery`.
- Public Devgraph: `../worktrees/devgraph/complete-integration`.

Pre-existing Wallet mobile-web/package-lock/changelog work and Devgraph maintenance work were preserved. The deprecated private Devgraph archive was not used. No roadmap objects were added to Devgraph.
