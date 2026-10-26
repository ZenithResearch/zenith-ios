# DevGraph discovery on Tailscale

Zenith's Work server picker automatically checks visible peers when its embedded
Tailscale connection becomes ready, and offers **Find servers on Tailscale** to
refresh. It does not require a Tailscale API token or Wallet unlock. Existing
saved connection files remain a separate section.

The embedded node's status yields peer MagicDNS names. Zenith probes HTTPS on
443 and the Zenith service bootstrap port 9443. A bounded optional
`/.well-known/zenith-services.json` directory can advertise additional HTTPS
origins on that same peer: `{"schema":"zenith.service-directory.v1","origins":["https://graph.example.ts.net:10443"]}`.
Each result must then return a supported `/.well-known/devgraph-connection.json`
and pass canonical service-binding negotiation. This is public metadata, not
issuer trust, enrollment, membership or a credential. The user reviews the
selected server before saving; Wallet proofs are sent only in the subsequent
explicit access flow.

Probes use the embedded Tailscale route with failover disabled. Hostnames,
message sizes, candidate count, concurrency, response size and timeouts are
bounded. Cancellation, backgrounding or a network generation change discards
results. Directory advertisements cannot direct probes to another host,
cleartext, paths or credentials. Peer keys and complete status documents are
not retained or logged.

Tailscale peer visibility and access rules still apply. MagicDNS is device
naming, not universal application/port enumeration. Unadvertised arbitrary
ports, subnet-only machines, offline or hidden peers, and servers behind denied
rules cannot be promised automatic discovery. Enter their HTTPS address or use
a connection file. To be discoverable without typing, publish an accessible
DevGraph profile on 443/9443, or advertise its port through the directory there.
Discovery changes no network exposure or Tailscale access rule.
