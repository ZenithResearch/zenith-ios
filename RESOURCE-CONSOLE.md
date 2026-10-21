# Resource and credential console

Zenith Transfer build 6 is the first native Mac entry point for resource administration. It preserves encrypted recovery-file QR transfer and reuses the pinned Castalia native core; it does not mint grants from port numbers or introduce another credential authority.

## Available now

- **Resources & requests:** import a closed, bounded DevGraph public connection file, or fetch `/.well-known/devgraph-connection.json` from an explicitly entered HTTPS origin. Lookup sends no Wallet identity. The operator reviews the address, issuer, public key and optional LAN certificate pin before registration. Replacing settings shows both versions and rejects a stale saved record.
- **Per-resource inbox:** open the exact origin's `/monitor/access/` in the user's browser. That existing interface authenticates its operator Wallet, lists requests and grants, exposes Contributor/Project Manager presets separately from global/multiple hierarchical paths, reviews an exact selection and activates or revokes grants under the server's ceiling. Browser Wallet custody and browser HTTPS trust remain independent of this app. No issuer pin or leaf certificate is installed in the browser by registration.
- **Native Wallet:** create or explicitly import a recovery file, review the decrypted public identity before committing, unlock, export an encrypted recovery file and verify that backup. The existing Rust ABI owns all custody/decryption/commit operations. Password fields clear after submission, cancellation, leaving the Wallet screen or app deactivation. The Wallet locks on deactivation and after five minutes; it is never automatically unlocked for an inbox.
- **Transfer files:** the original encrypted-header catalog and animated QR producer remain unchanged.

Resource settings live under `Application Support/ZenithTransfer/Resources`, one bounded public connection file per origin, with 0700 directory/0600 files and coordinated compare-and-swap updates. Registry removal removes only that local registration. It does not revoke a grant, delete a Wallet or stop a service. Unknown fields, credentials, malformed records and linked stored files fail closed.

The native Wallet snapshot lives separately under `Application Support/ZenithTransfer/Wallet`. No automatic reads of the Chrome or main Zenith Wallet databases occur. Imported identity does not imply installation identity, issuer trust, membership, server ownership or operator admission.

No server address, identity, TLS fingerprint, preset or synthetic test resource is bundled as a product default. Other secS/Hub resources are not yet supported merely because they run on this Mac. Registration cannot establish ownership or elevate the operator.

## Native approval boundary

The pinned native Wallet core permits `access.request` and `access.status` through its member-request consent API. It deliberately rejects `access.inbox`, `access.review` and `access.decide`. The browser consent API supports those operations. A real-core regression verifies the distinction using a backup-verified disposable Wallet and a valid positive member challenge.

Therefore build 6 opens the browser's existing grant interface; it does **not** provide native inbox proof/decision signing or an embedded grant editor. Unlocking the Transfer Wallet does not unlock Chrome. Current active grants can be inspected/revoked in the browser; editing an active grant without a new member request requires the separately planned revision contract. A 120-second approval challenge is not the standing grant lifetime. Until-revoked grants remain valid subject to revocation and independent transport/issuer/signing-key validity.

## Completion work

Tracked canonically by `Task/zenith-transfer-resource-credentials` under `Issue/devgraph-access-mvp-delivery`.

1. Add explicit, versioned native operator consent to Castalia. Keep member consent unchanged. Validate exact receiver/issuer/Wallet/installation, action schema and operation, policy revision/digest, request version/digest, previous assignment digests, selection and validity. The renderer must receive a complete verified summary and old/new differences; no generic sign-bytes API or fabricated browser caller. Lock, cancellation, expiry and identity change invalidate one-use previews.
2. Rebuild the pinned native ABI/XCFramework with provenance and producer/consumer vectors. Older native cores advertise no operator capability; fail closed with a clear update requirement. Do not weaken membership-free member access to obtain operator signing.
3. Implement the native DevGraph adapter and request inbox. Persist the exact original action, origin, identity, request version and assignment digests before any possible dispatch. A lost response or restart allows original-action status recovery only. Never blindly retry an activation with a new action ID or silently turn it into a new request. Shared browser/native selection contracts must agree on global scope, unions of hierarchical roots and resource membership at the time of access.
4. Implement the separately versioned standing-grant revision contract: authenticated current-state prefill; explicit attenuation versus broadening; atomic read/write replacement and audit; monotonic revisions and revocation high-water marks; exact old digests and safe race recovery. Existing approval signatures must not acquire new edit semantics.
5. Define a resource management capability descriptor and owner-signed service identity for Hub/secS registration. Discover public candidates, independently review trust/ownership, verify capability compatibility, then register an adapter. Discovery never grants operator access. Do not infer a generic credential factory from DevGraph's product-specific action schemas.
6. Qualify actual included/excluded reads/writes, retained credential revocation, changed/future/moved descendants, stale approval races, restart recovery, multiple resources, and physical iPad picker/write use. Keep Nostr/Matrix notifications, cross-graph sync and moving this shell into the main Zenith app separate from this direct provisioning MVP.

## Verification

`swift build --product ZenithTransfer`, `swift test`, and `sh scripts/build-transfer-app.sh` use Xcode's toolchain. Registry tests cover multiple resources/reopen, exact inbox address, file permissions, stale issuer replacement/removal across instances, malformed/secret-bearing records and links without overwriting the source. Native tests cover actual encrypted Wallet round trips and reject operator signing through member consent. Visual review and a human-controlled import/unlock remain separate from these tests; no real Wallet is created or imported by test setup in the shipping app.

The app icon is packaged from the established `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. The build remains ad-hoc signed local development software, not notarized distribution.
