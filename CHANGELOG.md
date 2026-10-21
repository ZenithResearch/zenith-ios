# Changelog

## [Unreleased]

### Added

- Discover owner-protected services from ~/.zenith/resources/v1 in Transfer build 9 — review public local connection settings without manually finding a server URL or importing authority. Separate configured monitors from Wallet-ready HTTPS services and keep saved issuer/TLS pins unchanged until review.

- Add opt-in password reveal and explicit Copy controls throughout Transfer Wallet — allow inspection and native paste without showing or copying passwords automatically. Build 8.

- Add explicit native operator consent and a bundled, origin-bound DevGraph grant editor in Transfer build 7 — keep private signing inside Castalia while preserving original-action recovery after uncertain responses. Native member consent remains narrow.
- Share the discovered recovery-file catalog between Wallet import and QR transfer — select existing backups by filename, date and folder without browsing again; distinguish data files and re-read recovery contents before identity review.

- Add the Transfer resource registry, isolated native Wallet setup and per-resource browser inbox entry — reuse the working grant flow while explicitly refusing to pass native operator approvals through member consent. Build 6 reuses Zenith artwork and preserves file transfer; native operator signing and generic service adapters remain open.

### Changed

- Reuse the recovery-file password for Transfer’s local unlock by default, while allowing a separate local password — avoid forcing an unexplained replacement password. Show the native minimum before submission, keep the selected encrypted file after failed preparation and display only closed Wallet error messages.

- Reject stale-path symlinks before coordinated encrypted-file reads and open descriptors without following final links — cached discovery metadata must not redirect Wallet import. Stage packaged app replacements instead of overwriting a running executable.

- Use a bounded native resource tree with explicit inherited coverage — global requests and multiple container roots must remain separate from operation presets without rewriting stored requests.

- Separate permission presets from a global request or multi-select resource hierarchy — retain exact v2 preferences while making descendant inheritance and multiple Arena/Initiative/Project roots explicit.

- Use the versioned native graph API and verify its ABI while preserving existing Wallet data — graph requests depend on custody/backup and resource policy rather than a universal community membership gate.


### Added

- Add the explicit dated/until-revoked grant validity reader and common rejection/attenuation vectors — mobile clients need the same lifetime semantics as the server while old connections remain unchanged.

### Added
- Native server preset and Arena/Initiative/Project request picker with exact path disclosure and scoped-read compatibility — members can request reusable access without pasted credentials, while rejected preparations and lost responses preserve safe recovery. Build 22 updates the existing app without changing Wallet custody.


### Fixed

- Open Membership in a dedicated sheet with a return to the saved Work server and consume setup continuation once — avoid navigation cancellation interfering with joining and premature read attempts before operator access is assigned. Development build 21.

### Added

- Replace the placeholder Z with the existing ZenithOS brand artwork and retain its source provenance — use the real Zenith identity on the Home Screen and welcome screen. Development build 20.
- Add a mint Zenith app icon and matching welcome mark — make the installed app recognizable on the Home Screen. Development build 19.
- Add public HTTPS server discovery and native request/status consent with durable request IDs — remote members can request access and recover uncertain responses without pasted credentials or duplicate requests.

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
