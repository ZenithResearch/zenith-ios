# Private Work connections

Zenith uses the official TailscaleKit wrapper over libtailscale. The embedded userspace node belongs to this app installation; it is not the separate Tailscale app or a device-wide VPN. The shared Castalia Rust core remains unchanged.

For a server on the same Wi-Fi, [Local network setup](LOCAL-NETWORK.md) provides a separate HTTPS route. Use **Change connection** to choose a saved connection file; Tailscale remains available. There is no automatic route fallback.

## Reviewed journey

The UX and lifecycle review selected one Connection picker and one status/action row:

1. Open **Settings → Network**, or **Work → Connection** when choosing a server.
2. **Sign in with an auth key** is the primary enrollment action. Generate a separate one-time, non-ephemeral key for each app installation. Leave Reusable and Ephemeral off; leave Tags unset for a personal device and retain device approval when enabled. The in-app enrollment sheet links to the official Keys page. A key's enrollment expiry does not itself disconnect an already registered device.
3. Paste or import the key, then choose **Enroll this device**. The entered key is cleared on submission or leaving the screen. Normal reconnects use the saved node identity. Browser sign-in remains an explicit secondary action; key enrollment never silently falls back to it. Administrator device approval may still be required.
4. For a server address, **Use Tailscale** remains available and initially enabled in new drafts. Once connected, **Find server** fetches same-origin public verification settings through the embedded node and retains `network: "tailscale"` when saving. Turning the toggle off explicitly selects direct HTTPS. Alternatively, choose a saved connection file. Selecting a file alone never starts enrollment.
5. Review **Continue to read access** and the server verification details before saving. Request or check the operator's access decision, then review the provider-signed reusable grant before saving it in Wallet. Temporary read access remains available. Community membership is separate from graph access. Connection checks and saved network management remain available afterward.

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
