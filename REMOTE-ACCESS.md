# Remote Work access — build 18

Work → Connection accepts an administrator-supplied HTTPS address. **Find server**
fetches only `/.well-known/devgraph-connection.json`, with no Wallet identity,
proof or credential. A bounded, same-origin profile is displayed for explicit
review before it is saved. Redirects, another receiver and secret-bearing profiles
fail closed. Public HTTPS uses the normal system certificate checks; no Tailscale
login or LAN certificate pin is added implicitly. File/manual/private setup
remains supported and existing saved settings remain readable. Previewing a public
server does not disconnect the shared Tailscale session used by Chat; the selected
Work route still uses direct HTTPS and never falls back across networks.

After unlocking a Wallet with active membership, **Request or check access**
prepares the server-owned request. **Send access request** displays the server and
purpose and explicitly approves only that request. The operator then selects and
activates a grant within its own policy. Pending is not connected. **Check request**
asks only for the original request’s status. **Continue** separately fetches the
exact read scope for Wallet approval; a grant may be reused while valid.

Only the receiver, public Member Key, installation and random request ID are saved
outside custody. They are device-protected, excluded from backups and bound to the
selected receiver/identity/installation. No signature, membership proof, token,
password or recovery file is saved there. A lost response never starts another
request automatically. If an authenticated status check reports unknown, an
explicit resend reuses the exact original ID and unspecified intent.

The shared native core is pinned to d89580e. Its new prepare/approve operations
admit only access.request and access.status, consume a one-use token, and clear on
lock, cancel or state replacement. Native apps do not claim a browser caller.
Membership, encrypted snapshots, recovery formats, read credentials, signing
transcripts and old native-v2/monitor-v3 read handling are unchanged. Work mutation
signing and native operator grant decisions are not added by this phone update.

## Checks

The actual native-core Swift suite passes 71 tests with 2 optional skips. It verifies
the request signature, one-use consent and lock invalidation, and simulates a lost
submitted response followed by status recovery with the same ID and only one
submission. Public profile discovery, redirects/receiver changes, public metadata
persistence and legacy reads are covered. Full Simulator and signed iPhone builds
pass. Device installation and cellular/remote reads require separate observed
results; a build or ngrok health probe is not a physical-phone qualification.
