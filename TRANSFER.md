# Zenith Transfer

Companion build 6 adds a **Resources & requests** console and an isolated native **Wallet** beside the existing **Transfer files** helper. See [RESOURCE-CONSOLE.md](RESOURCE-CONSOLE.md) for the current implementation and native approval work still required. File discovery and QR transfer remain local and do not unlock or import anything by themselves.

Build 3 adds **Scan laptop QR** and **Use USB cable** to recovery selection, backup checking, and data-file import. Choose the matching destination: a recovery file restores signing identity; an ordinary Castaway data file requires a matching wallet. Transfer never performs the import itself.

## QR: the image carries the file

On a Mac, build the companion with `sh scripts/build-transfer-app.sh`, then open `Artifacts/Zenith Transfer.app`. Choose the encrypted file from the discovered list or use **Choose another file**. On the iPhone, choose **Import a wallet → Scan laptop QR**. Allow camera access when asked. Scan the laptop screen, enter the file password on the phone, choose the phone's new unlock password, review and confirm.

Companion build 4 lists files directly inside `~/.castalia`, Downloads and Documents. `~/.castalia` is the Web wallet's documented vault location; browser recovery downloads normally use the browser's configured download folder. Save dialogs can choose another directory, so these are discovery defaults, not a claim that every wallet forces the same save path. The companion never searches subdirectories. It considers `.castalia-recovery`, `.castaway` and legacy `.castalia-wallet` names, then validates bounded encrypted envelopes by content. Unsupported/damaged files remain visible with a reason and cannot produce a QR. Refresh re-reads the folders; selection revalidates the file before rendering one QR transfer at a time.

| Encrypted contents | Version | Label and purpose |
| --- | --- | --- |
| `castalia.wallet-custody.v1` | v1 | Wallet recovery; restores signing identity |
| `castalia.castaway.v1`, with `castalia.castaway-contents.v1` | v1 | Castaway data; requires a matching wallet |
| Custody v1 in an old `.castaway` or `.castalia-wallet` filename | v1 | Legacy filename; naming is deprecated, recovery contents remain supported |

Header inspection does not verify the encrypted contents, trust or membership proofs. No decryption, conversion, renaming or wallet mutation occurs during file discovery or QR transfer. Those tools do not access installed wallet storage, keys or credentials and never ask for a password. The separate Wallet screen now accepts passwords for explicit native create/import/unlock/backup operations, and Resources can look up public HTTPS connection settings and open the selected server's inbox in your browser. There is no server, listener, relay or pairing secret. This is a local development Mac app, not a notarized distribution build.

Companion build 5 shows a saved date and time on each file and its detail view. This uses the local file's last modification time, not the wallet creation timestamp or an inferred date from its filename. The list is ordered newest first across all discovered folders, with a stable path tie-breaker; unavailable dates appear last. The containing folder remains on each row, with folder scan details available below the list.

Small files use one QR. Larger files cycle through numbered parts every half second; keep the camera still until all parts are collected. Pause/Next on the Mac supports manually advancing parts. The phone shows progress, ignores duplicate frames and accepts out-of-order frames. After three minutes the scanner pauses and discards incomplete assembly. Backgrounding or cancelling also discards incomplete assembly and stops capture. Fully received encrypted selections may remain in memory through the existing unlock flow; passwords and prepared wallet previews do not.

QR transfer is limited to **64 KiB** to keep scanning practical. Larger files use USB/Files, with the existing **1 MiB** limit. No compression or decompression is introduced. A freshly generated recovery fixture was 685 bytes, but that measurement is not a guarantee about every historical or future backup.

A photo or screenshot of the QR is a copy of the encrypted backup. It cannot be made single-use or revoked by hiding the image. Keep the backup password separate. The final Rust validation and public identity review remain required; the transfer checksum does not prove who supplied a file.

## USB

On the iPhone, open **Use USB cable** to prepare the transfer folder. Connect and unlock the phone. On a Mac, open Finder → the iPhone → Files → Zenith and drag in the encrypted file. On Windows, use Apple Devices → the iPhone → Files → Zenith. Tap **Refresh** in Zenith, select the file and complete the existing password/review/import flow.

Only the app's Documents directory is shared. Wallet snapshots remain in Application Support and are never copied into Documents. The transfer directory is excluded from device backup and uses complete file protection on iOS. Other apps and the paired computer can access files deliberately placed in this shared directory; this is not an alternate custody location. The UI admits supported encrypted envelopes by content, not filename. Unknown/plaintext files, links, oversized files and directories cannot be imported. Files are read through a coordinated bounded snapshot and never edited.

The copied file remains in Files → On My iPhone → Zenith. Remove that transfer copy yourself after checking the import if desired; keep the original backup. No automatic deletion or claim of secure erasure is made.

## Version 1 QR contract

Each QR contains an ASCII string:

```text
ZENITH-FILE:1:<sha256>:<file-byte-count>:<part-number>:<part-count>:<base64url-part>
```

- The digest is the lowercase SHA-256 of the complete, unchanged encrypted file.
- Split the original bytes into 720-byte chunks; only the final chunk may be shorter. Part numbers start at 1, and part count must agree with the full length.
- Base64url is unpadded and canonical. Integers are canonical positive decimal values. Each frame is bounded to 1,100 UTF-8 bytes; the complete file is bounded to 65,536 bytes.
- The first accepted frame selects one digest/length/count. Mixed transfers fail. Identical duplicates do not advance progress; conflicting duplicates discard assembly. The final byte count and digest must match before envelope admission.
- Q error correction, a white quiet zone and integral scaling are used for rendering. Frame order and refresh cadence are not part of the byte contract.
- Unknown versions, malformed frame fields, unsupported envelopes and oversized payloads fail closed. An ordinary URL is never followed or opened.

The Mac producer and iPhone consumer share `RecoveryQR` in ZenithKit. Python-generated independent vectors in `Tests/ZenithKitTests/Fixtures/qr-file-v1.json` pin framing against the historical public custody fixture. This additive transport contract does not change custody/Castaway schemas, encryption parameters, signing domains, grants, or the shared Rust/WASM core. The envelope admission check is not cryptographic verification: Rust still authenticates the file, checks the identity, stages restoration and enforces the confirmed transaction.

## Verification

Run `swift test`, `sh scripts/build-transfer-app.sh`, and the iOS Simulator/device builds. Tests cover independent vectors; real Core Image → Vision QR decoding; out-of-order, duplicate, mixed and corrupt frames; malformed/oversized data; source-file preservation and link rejection; and actual QR reconstruction → Rust recovery, including wrong-password and existing-wallet rejection.

Physical acceptance must separately exercise camera permission denial, a laptop screen at different distances/brightness, animated capture, cancellation/backgrounding, a real Finder/Apple Devices cable copy, Files-provider interruption, and the final recovery/password/review flow with a disposable identity. Simulator camera availability and source tests cannot qualify the actual optical or cable transfer.
