# Work over the local network

Build 13 adds **Local network** alongside Direct HTTPS and Private via Tailscale. Join the same Wi-Fi as the work server, choose its connection file, allow Zenith's Local Network permission, then approve the displayed read access. Tailscale sign-in is not required for this route.

For a configured wallet, use **Work → Connection → Change connection**. Connection files in Zenith's Documents folder remain available, so the person can select either route later. One Work connection is active at a time. Changing it requires fresh read approval; there is no automatic fallback between networks. Wallet identity and membership are preserved.

## Public connection file

The existing file remains compatible. LAN files add `"network": "lan"` and `"tls_certificate_sha256"`, the lowercase SHA-256 digest of the server's exact DER leaf certificate. Both fields are required together. Direct/Tailscale files must not contain a LAN certificate pin; old clients reject LAN files rather than silently using an unverified route.

```json
{
  "name": "Work on Wi-Fi",
  "receiver": "https://work.example.local:9444",
  "issuer": "example-issuer",
  "authority": {
    "issuer": "example-issuer",
    "key_id": "example-key",
    "public_key": "<64 lowercase hexadecimal characters>",
    "receiver": "https://work.example.local:9444",
    "audience": "devgraph"
  },
  "network": "lan",
  "tls_certificate_sha256": "<64 lowercase hexadecimal characters>"
}
```

Generate this public file from a separately reviewed receiver policy and certificate:

```sh
python3 scripts/create-lan-profile.py \
  --authority-policy /operator/lan-authority-policy.json \
  --certificate /operator/server.pem \
  --output /operator/Work-server-LAN.json
```

The script copies only public pin fields, never permissions or private keys. It does not create an issuer, configure a service or grant access. Give the file to the person through an approved channel such as USB/Finder. The app previews its server and certificate details before saving. No deployment profile, local address, private hostname or key is bundled in source or the app.

## Server requirements

Serve only the guarded read receiver over TLS 1.2 or later, with a strong server certificate matching the chosen DNS name or IP SAN and a current validity interval. A self-signed certificate is supported through the reviewed per-server fingerprint. The app checks the exact certificate, hostname, port, validity and server-use policy. It does not accept a certificate merely because a handshake failed, install a device-wide CA, enable plaintext HTTP or fall back to default trust for mismatched pins. Certificate renewal requires a new reviewed connection file.

Configure the receiver and issuer policy for the exact LAN HTTPS origin. Credentials and holder proofs remain bound to that origin; a Tailscale credential cannot be silently reused at another receiver. Keep the intended grants, membership trust, revocations, secS verifier and Devgraph scope enforcement. A separate listener can use the same existing issuer with an independently reviewed receiver policy and separate enrollment storage. It must not expose the main API or database directly.

Bind the listener only to the intended private interface. A fixed binding must be updated if DHCP changes the address; `.local` names also require mDNS reachability. Guest Wi-Fi/client isolation can prevent access. Do not open a router port or change Tailscale Serve/Funnel just to enable LAN.

## Qualification

Native tests exercise old/new file compatibility, missing pins, mismatched route/pin, wrong origin before dispatch, hostname/port, certificate substitution, expiry/not-yet-valid dates, and server-versus-client certificate use. The optional `ZENITH_LAN_TEST_PROFILE` test exercises a real HTTPS listener and rejects a wrong pin, without sending identity or credentials.

Separately test on an iPhone: allow/deny Local Network, approve read-only access, read a page/item, background/unlock, switch back to Tailscale, and leave Wi-Fi. A Mac TLS probe is not physical-device qualification. Rust custody, membership and signed-read request/credential contracts are unchanged.
