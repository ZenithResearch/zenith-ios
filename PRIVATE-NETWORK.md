# Private Work connections

Zenith uses the official TailscaleKit wrapper over libtailscale. The embedded userspace node belongs to this app installation; it is not the separate Tailscale app or a device-wide VPN. The shared Castalia Rust core remains unchanged.

## Reviewed journey

The UX and lifecycle review selected one Connection picker and one status/action row:

1. Open **Work → Connection** (also available from **Wallet → Work access**).
2. Enter the server's HTTPS address or import its public connection file.
3. Choose **Direct** or **Private via Tailscale**. Selecting Private does not enroll or connect automatically.
4. Tap **Connect Tailscale**. Sign in using the system browser and join the network supplied by the server administrator. Administrator device approval may still be required.
5. **Check connection** sends an empty, credential-free probe to the closed read endpoint.
6. Independently review the issuer public key and save the server, then review and approve its exact read permissions and expiry.

A network connection is not a successful server probe, issuer verification or read authorization. No public/private host, tailnet name, reusable auth key or operator key is bundled. The official public Tailscale control plane is the only supported control plane in this preview. Headscale/custom control planes and multiple simultaneous networks are outside this change.

## Boundaries and lifecycle

- `App/Networking/TailscaleDriver.swift` owns the TailscaleKit adapter. `Sources/ZenithKit/PrivateNetwork.swift` owns the testable state machine. Neither receives Wallet keys, membership proofs or read credentials.
- `App/Networking/PrivateNetworkView.swift` owns status, system-browser sign-in and network management. It never examines sign-in page contents. The auth URL is HTTPS, host-validated and held only in memory.
- `WorkServerDraft` holds public setup fields in memory across locking. Unlocking returns to unfinished setup. No draft silently installs trust or starts enrollment.
- Every private Work HTTP request obtains an ephemeral session configured through the embedded node. No cookies, URL credential store, cache or redirects are allowed. HTTPS certificate validation remains standard. Proxy failover is explicitly disabled.
- The native client rejects a private configuration with no supplied private transport. Membership transport remains separate. Tailscale does not broaden any issuer/secS/Devgraph grants or Arena scope.
- Backgrounding cancels HTTP sessions, closes the node and clears auth URLs. Foregrounding rebuilds the node/listener for an already requested connection. Wallet locking is unchanged. Stale callbacks and session configurations are rejected by generation.
- Node state lives in an app-private, complete-file-protection directory excluded from backups. Tailscale node keys are distinct from Wallet custody and never enter `.castaway` or recovery exports.
- **Disconnect Tailscale** pauses networking and retains the node's local sign-in state, server settings and read approval. Remove the device using Tailscale's admin console to revoke network membership. **Remove read access** removes only the app's saved Devgraph authorization.

## Pinned build

`Dependencies.json` pins libtailscale commit `258321b9f7354b150488953f7a47918a5eb4b96b` (Tailscale `v1.104.1`) and Go `1.27.2`. `scripts/build-tailscale.sh` verifies the source revision and permits only the checked logging patch. Go module checksums are verified before building arm64 iPhone and arm64 Simulator frameworks. The framework requires iOS 18.1; the reusable Wallet package remains compatible with its earlier targets.

The small downstream patch disables logtail buffering/uploads and discards the default user logger, which otherwise prints interactive auth URLs. The Swift logger also discards output. The wrapper's `down()` is not used because it calls `up()` in this pinned revision; closing/recreating the node also avoids cached loopback listeners across iOS suspension. Direct `statusJSON()` supplies status without depending on the loopback HTTP server.

`Artifacts/tailscale-build.json` records public pins, patch checksum, toolchain and framework-file hashes. Generated binaries, build output, node state and local deployment profiles remain ignored. Third-party notices accompany the application.

## Qualification boundary

Unit tests exercise minimal status decoding, untrusted auth URLs, explicit connection, cancellation, stale completion, suspend/resume, pending configuration cancellation and no direct fallback. Existing transport, custody, recovery and persistence regressions remain required.

Simulator checks cover actual embedded startup to the official sign-in page and cancellation plus native layout/accessibility. They do not authorize a tailnet or prove a real private read. Physical-device sign-in, administrator approval where applicable, network switching, background/foreground recovery, and a holder-bound Devgraph read still require the user's account and selected server. Record these separately from source/build success. No production grants, trust settings, service routes or public exposure are changed by installing this app update.
