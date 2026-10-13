# Zenith iOS preview

A greenfield, native SwiftUI app with **Work** and **Wallet**. Castalia Wallet owns custody; Devgraph owns read authorization and work data. This implements the reviewed Zenith roadmap without changing the existing iOS app, phone website, live identities, trust, grants, or graph.

Status: source implementation and Simulator build; **not a qualified release**. See [implementation status](IMPLEMENTATION-STATUS.md) and [qualification](QUALIFICATION.md).

## Build

Requires Xcode, XcodeGen, Rust with `aarch64-apple-darwin`, `aarch64-apple-ios-sim`, and `aarch64-apple-ios` targets, and the Castalia Wallet revision in `Dependencies.json`. Dependencies must be available to Cargo's offline cache. Minimum iOS is 17; the development bundle is `ca.zenith.preview.wallet`. No signing team is committed.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scripts/build-core.sh /absolute/path/to/castalia-wallet
xcodegen generate
swift test
xcodebuild -project Zenith.xcodeproj -scheme Zenith \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derived-data CODE_SIGNING_ALLOWED=NO build
```

The XCFramework contains arm64 iOS, Simulator, and macOS libraries from the same Rust source. `Artifacts/core-build-manifest.json` records the source and library hashes. Generated builds, logs, and Simulator artifacts are ignored. Xcode signing/distribution and physical-device installation are separate steps.

### Install a development build on an iPhone

Pair and unlock the iPhone, and sign in to the intended development team in Xcode Settings → Accounts. The project disables signing by default for reproducible source checks; override it for the device build without committing a personal team or provisioning profile:

```sh
xcodebuild -project Zenith.xcodeproj -scheme Zenith -configuration Debug \
  -sdk iphoneos -destination "platform=iOS,id=$ZENITH_PHONE_UDID" \
  -derivedDataPath .derived-data-device \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$ZENITH_TEAM_ID" -allowProvisioningUpdates build
xcrun devicectl device install app --device "$ZENITH_PHONE_UDID" \
  .derived-data-device/Build/Products/Debug-iphoneos/Zenith.app
xcrun devicectl device process launch --device "$ZENITH_PHONE_UDID" \
  ca.zenith.preview.wallet
```

Use the selected phone's identifier and approved team ID for these variables. A certificate alone is insufficient when the matching provisioning profile is absent. If installation or launch requests device-side setup, complete it on the phone before retrying. Never uninstall the app to work around signing or launch errors: that can remove wallet storage.

The phone has its own wallet storage. Installing the app does not copy Simulator custody. Create a disposable wallet or explicitly restore its encrypted recovery file through the app. Membership and work access still require the separate configuration and approval below. Successful installation is not completion of the physical-device qualification checklist.

## Product behavior

- A new installation starts with exactly two choices: **Create a wallet** and **Scan to import**. Create opens the local-password page; Scan opens the camera immediately. The journeys use separate screens and navigation state.
- Import an encrypted file by scanning a laptop QR or copying it over USB. The [offline transfer guide](TRANSFER.md) covers the Mac companion, USB steps, protocol and device checks. QR carries the file itself; no network connection or upload is used.
- Create a wallet, save an encrypted recovery file, select that actual file, and check its password. Membership and signing remain unavailable until the check succeeds.
- Restore an encrypted recovery file and optional data file, each with its own password. Review the public identity and imported sections before saving. An existing wallet cannot be replaced.
- Import `.castaway` data only into the matching unlocked identity. Profile/proof replacements are previewed; absent proofs are preserved. Export can recover the supported data again. Nothing is published.
- Legacy raw recovery **input** remains under recovery help and requires creating/checking an encrypted backup. There is no ordinary private-key reveal, copy, or seed phrase.
- Membership and Work access are distinct, explicit choices. A restored membership proof remains inactive. Restored data never reinstates a read credential.
- Work presents bounded pages and one type filter; the search is explicitly over loaded work. Unknown legacy progress is “Progress not recorded.” The receiver's legacy read projection currently admits Proposal, Initiative, Project, Issue, and Task; base Todo and canonical progress require a later delegated-read contract extension, not inferred lifecycle values.

The interface uses native forms, lists, file pickers, a scrolling welcome screen, adaptive accent color, public detail disclosure, and a privacy cover while inactive. A saved file-selection may survive in memory as encrypted bytes; passwords and previews do not survive locking.

### Onboarding modules

- `App/RootView.swift` selects welcome, unlock, incomplete backup setup, completion or the main app.
- `App/CreateWalletFlow.swift` creates the identity. `App/BackupWalletFlow.swift` owns saving and checking the actual recovery file, and is reused from Recovery settings.
- `App/ImportWalletFlow.swift` owns selection, backup password, local password and prepared review/confirmation. Optional data is isolated in `App/RestoreDataAttachmentSheet.swift`.
- `App/WalletFlowComponents.swift` shares page layout, persistent password labels, compact file summaries, encrypted-file selection and completion UI. It does not perform custody or storage operations.

Each page has one next action. Alternative transfer methods are secondary; after selection they collapse to a file summary. The review page appears only after Rust validation. A successful encrypted restore satisfies the existing backup check; a new wallet must save and test its backup before proceeding.

## Configuration and consent

An unconfigured build intentionally offers setup-required states. Do not paste a local owner credential into the app or ship a test trust root.

A distributor may supply **public proposed configuration** as `App/Membership.json` and `App/WorkAccess.json`, then regenerate the Xcode project. Loading either file does not approve it. The member must review and approve trust and read access in Wallet. Keep installation-specific configuration out of source control; record its public digest with the release evidence.

`Membership.json` has `name`, an HTTPS `endpoint`, optional `scope` (the canonical v4 community ID), and `trust`. Trust contains `v3` and/or `v4` using the existing Castalia policy schemas. For v4, scope genesis, issuer list and signature roots must agree. Omitting `scope` selects compatible v3 membership. These are issuer public keys, never private keys or bearer credentials.

```json
{
  "name": "Zenith work",
  "receiver": "https://your-approved-receiver.example",
  "issuer": "your-approved-issuer",
  "authority": {
    "issuer": "your-approved-issuer",
    "key_id": "your-approved-key-id",
    "public_key": "<64 lowercase hexadecimal characters>",
    "receiver": "https://your-approved-receiver.example",
    "audience": "devgraph"
  }
}
```

The example is the shape of `WorkAccess.json`, not an enabled service. The public Devgraph candidate exposes an explicit `create_signed_read_app` composition with independently configured membership verification, read policy, graph storage, audit log and private enrollment database. See its `docs/native-signed-read.md`. Provisioning requires an active, trusted membership and a fresh proof of possession; membership alone grants no work access. The native app displays the exact server, issuer, work scopes, archive visibility, and expiry before approval.

The issuer public key must be supplied independently of the enrollment response. The shared Rust core validates the signed credential and signs a fresh holder proof for each read. Old bearer-only Work configurations fail setup.

Read credentials are encrypted in the local snapshot and excluded from portable backups. URLSession is ephemeral, uses HTTPS, has no cookie/cache storage, rejects redirects, and bounds responses. Disconnect removes local access; server-side installation revocation is a separate operator action. No mutation client is included.

## Custody and transaction boundaries

`WalletRepository` is a Swift actor around an opaque Rust C ABI. Rust owns keys, portable validation, prepared imports, approval state and encryption. Swift sees public previews and encrypted snapshots. An immediate lifecycle gate plus task cancellation invalidates pending work on cancel, backgrounding, or device lock.

`SnapshotStore` saves one encrypted snapshot using SQLite `BEGIN IMMEDIATE`, expected-revision comparison, and durable commit. Core confirmation occurs after persistence completes. File protection is complete while the device is locked and the app directory is excluded from OS backup. This is password-encrypted app custody, not a Secure Enclave or hardware-wallet claim. If a commit completes just as the app locks, the next unlock loads that complete record; it never exposes a partial restore.

The shared core remains application-neutral. Its internal recovery/read-approval operations are not browser provider capabilities. There is no arbitrary-sign method in the native bridge. Swift strings and platform file-picker buffers cannot promise complete runtime memory erasure; the app minimizes their lifetime and never logs or persists them in plaintext.

## Coordinated source

1. Castalia Wallet: shared `recovery_session`, portable contracts, generic read approval, native ABI and MIT core/presentation crates.
2. Public Castalia Web: checksum-pinned shared core, worker-owned staging, transaction-completion/CAS persistence, checked backups, reviewed imports and no raw-key output.
3. Public Devgraph: explicit read-enrollment adapter and bounded guarded reader. No secS/Wallet mutation-signing changes or activation are part of this release.
4. This app: XCFramework consumer, Swift storage/network boundary and native UX.

`Dependencies.json` pins the exact Wallet commit. The core builder rejects a different revision or changed Rust inputs. Build manifests record source and binary hashes; physical-device results remain separate from source checks.

## Licensing direction

AGPL is the preferred direction for a future licensing review, as noted on October 12, 2026. This is not yet a relicensing decision: the AGPL version and affected repositories/crates remain to be confirmed. The previously approved MIT declarations remain current. Any migration should coordinate the native app, shared Wallet crates, public Web source snapshot, license notices, provenance and license checks so their declarations stay consistent.
