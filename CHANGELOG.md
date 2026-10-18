# Changelog

## [Unreleased]

### Added

- Prepare on-device speech to text in the Chat composer with explicit microphone permission, editable transcripts, bounded recording and cleanup on interruption/locking. Sending remains manual. Development build 17.

### Added

- Add explicit Tailscale auth-key enrollment with secure entry or a bounded text-file import in the shared Work/Chat connection screen. Keep browser sign-in and existing saved device identities; never replay enrollment keys on foreground resume. Development build 16.

### Fixed

- Let Hermes assign conversation titles — repeated New chat actions must not collide with its unique-title constraint.
- Keep chat authentication and oversized-response diagnostics separate from Wallet recovery errors — make gateway problems actionable without exposing error bodies.


### Added

- Add native text chat with a personal Hermes gateway over embedded Tailscale — let the iPhone converse with a normal Hermes profile while keeping its gateway key separate from Wallet custody.
- Persist a pending-send marker and reload server conversation history — avoid automatically sending a prompt twice after locking or losing the connection.


### Added

- Accept explicitly versioned monitor read scopes alongside historical native connections — let Zenith read Todos, canonical progress, full details and permitted relationships using its existing Wallet core.

### Fixed

- Follow server revision/cursor pagination and decode canonical string metadata — avoid missing modern pages or presenting a list summary as a complete item.
- Disclose granted operations and relationship types before read approval — keep native consent aligned with the exact issuer permissions.


### Fixed

- Add generic, device-local Work server setup with HTTPS address entry, optional Tailscale guidance, an anonymous connection check, and reviewed public issuer settings. Exclude Work configuration from builds; require explicit setup and fresh read approval after upgrading from a bundled preview. Development build 9.


### Changed

- Separate source qualification from installation-specific evidence; keep deployment settings and live device details out of public documentation.

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
