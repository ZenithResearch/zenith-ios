# Changelog

## [Unreleased]

### Added

- Pin shared Wallet build inputs and verify holder-bound read credentials for each Work request — let the native app connect to an explicitly approved issuer without an owner bearer.


### Added

- List encrypted files from the documented wallet folder, Downloads and Documents in Mac companion build 4. Disclose content-based v1 recovery/data formats and legacy filename status without decrypting or modifying files; retain unsupported files as non-transferable entries.
- Add offline encrypted-file QR transfer, a native Mac QR companion, and USB/Files import through a dedicated shared Documents folder. Preserve private custody in Application Support; validate and commit through the existing Rust core. Development build 3.
- Add a native Zenith app with Work and Castalia Wallet — provide simple membership, recovery and bounded read access without a phone website or mutation authority.
- Consume shared Rust custody through an opaque native ABI and transactional encrypted storage — preserve native/WASM identity compatibility and prevent partial or stale restores.
- Require checking a saved encrypted recovery file before new-wallet enrollment — replace self-attested backup confirmation with an actual recovery test.
- Add exact-artifact source evidence and physical-device/usability gates — distinguish implemented source from a qualified or activated release.

### Changed

- Split native onboarding into two complete journeys in iOS build 6: Create → save backup → check saved backup, and Scan to import → backup password → local password → review/confirm. Extract dedicated flow modules and reusable page, password, file-selection and completion components. Keep optional data and alternate transfer methods out of the main form; improve dark-mode contrast and persistent field labels.
- Show each companion file's saved date/time and order the entire list newest first across folders. Companion build 5; encrypted files and recovery behavior unchanged.
- Present Create and Import as equal welcome-screen choices, with consistent import labels through recovery. Development build 2.
