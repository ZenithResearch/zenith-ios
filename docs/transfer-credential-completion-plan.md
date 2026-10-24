# Transfer credential-setting completion plan

## Current checkpoint: native local RPC accepted; iPad client installed; hardening audit underway

iOS build26 applies the user's app-lifetime unlock policy on both iPhone and iPad:
background/device-lock pauses network and pending approvals, retains in-memory
Wallet custody, and resumes only after cancellation. Explicit Lock wallet and a new
process start locked. The privacy overlay and complete encrypted-file protection
remain; no new session, persistent unlocked key or broader credential is created.
Build25 was the last verified iPad install; build26 installation and actual mobile
switch-away/return acceptance must be recorded separately.

Build29 implements the requested one-hour native Transfer unlock policy with
configurable timeout and explicit-lock/quit mode, no app-deactivation lock, one
app-scoped Wallet across windows, fixed-from-unlock timing and immediate pending
consent invalidation on lock. The public-key hint is informational only. No grant
validity, signing authority, HTTPS/Tailscale configuration or iPad behavior changes.
Native expiry/persistence/relaunch tests use disposable Wallets and injected clocks.
This does not close the audit's cross-window journal/CAS finding: sharing one core
reduces separate-session races but is not a substitute for atomic action binding.

2026-10-23 publishing direction: Transfer is the control surface for both private
Tailnet (Serve) and public internet (Funnel) publication, per selected service.
The first native “Sharing & network” screen reads real Tailscale state, prepares
separate private/public address proposals and exports a versioned review. It does
not activate either mode. Service-specific owner authorization, external-origin
binding, certificates and durable configuration recovery are still required.
Do not present the read-only review as working publication or iPad discovery.

Existing network state changes the earlier LAN-only plan: this Mac already has
Tailnet Serve on9443 forwarding to the legacy privateAPI8080, while the actual
Wallet HTTPS58754 is unproxied and bound to127.0.0.1. Existing Funnel-enabled
listeners for unrelated services must be preserved. All three supported Funnel
ports443/8443/10000 are occupied. Changing a listener’s visibility affects the whole
port, including its other paths; dedicated private/public ports or a separate node
are necessary. A public listener is also reachable through the Tailnet, but does
not provide a private-only address. Never overwrite shared listeners as a shortcut.

The publication-review schema is additive and separate from current resource,
connection and signed-admin contracts. It binds resource ID, selected service ID,
endpoint/profile digest, observed Tailscale revision and proposed URLs, with explicit
blockers. It carries no signature, credential, grant or runnable command. A future
apply/status adapter must revalidate those bindings and owner authority; it must not
interpret possession of the exported review as authorization. Remote services need
their host’s supported configuration adapter; registering a remote URL does not
authorize this Mac to proxy or administer it. Transfer remains the client.

Transfer27 was approved and opened. Actual DevGraph local selection shows Manage
credentials and Local secS RPC. After the user unlocked/continued, the authenticated
native owner inbox visibly loaded0pending requests, without an error. User now
controls Transfer; do not operate its controls unless requested. No member grant
was issued. Existing HTTPS58754, owner and policy32 remain unchanged.

The user explicitly approved iPad build25, and devicectl confirmed its in-place
installation on the paired iPad with the same bundle/team. No uninstall was used.
Post-install Wallet/UI behavior has not yet been checked. No hardcoded fixture
endpoint exists in app source. Build succeeded with the existing orientation warning.
The requested independent security/robustness review is recorded under
`audits/security-roundtable-20261022`; discovered defects must be triaged before
expanding the real service to the LAN. The audit itself changes no live authority.

The real service's HTTPS listener is loopback-only. An iPad cannot use its127.0.0.1
address. Do not copy that profile to the device, point it to synthetic18891, bypass
TLS, or invent an already-running LAN deployment. Actual LAN publication is the next
necessary server-control slice before a real iPad request can succeed.

### Next concrete native service-control slice: publish on this LAN

- Keep Transfer the client and DevGraph/secS the service host. Add a distinct
  owner-authorized publish endpoint command with proposed configuration digest,
  expected configuration revision, graph/service identities and durable action ID.
- Preserve the original signed graph-owner registration. Add an explicit signed
  endpoint binding rather than re-registering ownership, silently changing origins
  or pretending the current four access-administration operations authorize arbitrary
  service configuration. Version the Wallet consent contract for service changes.
- Review the exact LAN address/port, TLS certificate/pin/SANs, selected interface,
  owner, issuer and whether scope names are public before activation. No0.0.0.0
  default, automatic public tunnel, arbitrary shell/executable or permission expansion.
- Publish a separately identified LAN interface of the same graph while retaining
  the working loopback interface. Receiver/origin-bound inbox and grant state must
  be explicit. Transfer must discover/manage that locally owned instance over secS
  based on its verified local binding, not infer locality solely from127.0.0.1.
- Support prepare/review/commit/status and unknown-result recovery, exact job
  verification, readiness before discovery, and clear failed/partial status. Never
  retry an uncertain deployment or native admission with a new action ID.
- Share the actual public LAN connection file/QR to the iPad. User reviews its TLS
  pin and sends a request. That exact request appears in the matching native Transfer
  inbox; user selects custom actions/preset, hierarchy and validity, reviews/signs,
  then recipient redeems. Validate included/excluded work and renewal/revocation.

Configuration/deployment writes are still disabled in the installed RPC release.
This section is a reviewed implementation sequence, not an active LAN service or
claim of completion. No production exposure or additional authority was activated.

### Hardening gates and iPad discovery clarification (2026-10-22)

The independent roundtable reproduced a lifetime operator-result capacity failure,
unsigned challenge-pool starvation, denial-audit exhaustion, an RPC process-tree
deadline failure and a two-window original-action journal race. Exact findings,
conditions and synthetic evidence are in `audits/security-roundtable-20261022`.
Do not treat passing happy-path tests as evidence these cases are safe. Repair and
regression-test capacity/recovery and unauthenticated challenge admission before
publishing the actual service more broadly. Do not remove historical mutation
receipts merely to free capacity or automatically retry an uncertain grant.

The iPad Documents inventory contains only `Devgraph-LAN-read-test.json` and
`Devgraph-preset-LAN-test.json`. `WorkServerInbox` reads copied profiles; it does
not discover network services. Label that section “Saved connection files,” with
file origin and the exact endpoint visible, instead of implying nearby discovery.
Preserve the files and existing grants until the user explicitly removes them.

The discovery delivery sequence is:

1. Publish an explicitly reviewed HTTPS LAN instance for the actual graph, with
   a reachable address, certificate SAN/pin, issuer and service-instance binding.
   The existing loopback address must never be offered as usable on the iPad.
2. Immediately support exporting that exact public connection profile and QR
   from Transfer. Profile export conveys no bearer credential or Wallet secret.
3. Add explicit “Nearby servers” Bonjour browsing, separate from saved files,
   using an application-specific versioned service type and bounded metadata.
   Discovery is a candidate hint, not proof of ownership, TLS trust or a grant.
   Do not scan arbitrary ports or send a Wallet identity while browsing.
4. Review the chosen graph/service, HTTPS endpoint, owner/issuer identity and TLS
   fingerprint before saving. An advertised fingerprint is untrusted until paired
   against an owner-supplied QR/profile or independently confirmed fingerprint;
   never auto-pin a certificate obtained from an unsuccessful TLS handshake.
5. Validate the reviewed HTTPS metadata against the candidate instance and graph.
   Reject mismatches, unsupported versions, excessive metadata and changed pins.
   Explain unreachable, stale, duplicate and permission-denied states distinctly.
6. Test LAN privacy permission denial, cancellation/backgrounding, disappearing
   services, duplicate names, forged announcements, loopback addresses, wrong TLS
   pins, endpoint changes and stale saved files. Then verify the physical iPad's
   new request reaches the exact selected real graph's native Transfer inbox.

Bonjour broadcast, production LAN publication and new certificate trust are not
active. The above is the concrete implementation/acceptance plan, not a claim that
network discovery or the real iPad credential journey has already passed.

## Historical implementation plan: local native secS RPC

The following section records the pre-implementation plan. The current checkpoint
above supersedes its "not yet implemented" statements; acceptance and remaining
production-device qualification are deliberately separate.

User clarification on 2026-10-22 supersedes the earlier transport note: same-machine
Transfer administration must call the local secS Magik RPC directly, with no HTTP
hop. HTTPS remains for remote/browser/iPad connections. Transfer is the native
Wallet/client, never the HTTPS host. Local machine presence does not confer owner
rights. Existing production owner registration remains valid and is not repeated.

Verified implementation gap: TransferOperatorBridge currently sends signed challenge
and action bodies through PrivateTransport HTTPS. The inspected secS ingress uses
native bounded TCP framing, but has no registered DevGraph access-operator handler.
A direct local credential-management RPC path is therefore not yet implemented.
Do not label an HTTP-over-socket wrapper or an unverified Python subprocess secS RPC.

Required change and review boundaries:

1. Define versioned receiver-local operator operation descriptors for challenge and
   signed action execution, covering inbox, review, decision, revoke and original-action
   status recovery. Preserve packet v0/u8 compatibility; no generic shell/signing API.
2. Connect verified secS dispatch to the same DevGraph operator service/assignment
   state, hierarchy evaluator, native admission and audit/receipt handlers used by
   HTTPS. Do not duplicate a second grant registry or move product policy into secS.
3. Expose additive local RPC discovery bound to graph ID, service instance ID,
   receiver identity, protocol and verification pins. Registry metadata alone is not
   authority. Transfer selects that exact local service; remote selections retain
   pinned HTTPS. Never infer locality from an arbitrary user-provided URL or silently
   fall back to another service or weaker authentication.
4. Add the Swift native secS call adapter behind the existing guarded operator
   state machine. Retain Wallet custody/consent, exact action digests and the durable
   pre-dispatch journal. Preserve original action IDs across transport errors; use
   status-only recovery for uncertain decisions, including cross-transport recovery.
5. Qualify native RPC and HTTPS against the same server state: unauthorized Wallet,
   changed receiver/graph, bad signature, expiry, replay, stale policy/request/selection,
   scope exclusion, revocation, denied delegation and wrong response binding must
   fail before mutation. A lost response must recover the same result without a
   second grant. Local grant is visible remotely and vice versa. Use synthetic
   principals first; actual production issuance still requires exact reviewed approval.

This is an additive producer/consumer contract change, not an installed claim.
Existing HTTPS profiles, retained owner proof, member requests, grants and action
journals must continue loading. No new production listener, native authority change
or member grant is activated merely by this plan. Onward delegation remains disabled.

Reviewed against source and installed state on 2026-10-22. This supersedes the
older build14 completion checklist in the execution evidence. The deliverable is
an operator using the native Transfer application to configure and issue access
to the actual configured DevGraph. Completing fixture tests, an owner form or a
saved setup plan does not complete that deliverable.

## Main user journey

1. Select a launched **Wallet API** instance for **DevGraph on this Mac**, stable
   resource `[local configuration]`. Instance identity and endpoint
   are separate from the graph identity and its private API at
   `http://127.0.0.1:8080`. Keep the selected endpoint throughout owner setup.
   Never substitute the synthetic graph on port18891.
2. Bind the owner's chosen Transfer Wallet through the local owner-controlled
   setup and the matching proof-of-possession boundary. This is one-time service
   setup, separate from the permissions issued to a member. Merely discovering a
   service, importing a Wallet, saving a public connection or saving a setup plan
   must not confer ownership.
3. Open **Credentials & requests** in Transfer. Authenticate the admitted owner
   Wallet, retrieve the real server inbox and select the requesting Wallet.
4. Choose a server preset, local recipe or custom actions. Presets describe
   permissions; they never imply a resource scope. Recipe/Seat metadata alone
   conveys no authority. Unavailable operations must be visible, not advertised
   as an active entitlement.
5. Choose explicit whole-graph coverage or several named Arena/Initiative/Project
   branches. Show human titles, typed IDs and inherited selection. Everything
   beneath a selected container is evaluated at access time: new descendants are
   included and moved-out work loses access. Related objects outside scope stay
   inaccessible. Empty selection and failed hierarchy loading never become global.
6. Choose **Until revoked** or an explicit expiry. This is the standing grant's
   validity; short-lived read credential redemption is separate and does not
   require another operator decision while the grant remains valid.
7. Review the exact recipient, read installation binding, write holder binding,
   operations, correlated filters, scope roots and validity. Confirm the exact
   native Wallet decision, activate at the receiver, and read back the result.
8. The iPad uses that actual connection and redeems its approved access. Verify
   permitted reads and writes, excluded work, reuse and revocation. No recurring
   fixture-request or temporary three-hour-window ceremony is part of this flow.

Onward delegation remains disabled. Do not show a second, larger per-Wallet
"maximum that may be delegated" selector in this credential flow. Current grants
are leaf grants. Future child-credential authority is a separate versioned task.

## Implementation and evidence matrix

## Current checkpoint: actual owner registered; native credential manager open

Build26 is open and the user personally signed the retained owner registration.
Owner Wallet [local configuration]ed77509ed0f133856ed4d2f586abc7c845b2e11e62cb1265
is verified for actual graph [local configuration]. Native policy
31→32 completed, preserving the same signing key/deadline, 48 historical rules
and existing agent readiness. No member grant was created.

Original activation stopped at listener start, after native provisioning. Read-only
preflight verified the original job absent and port unused, owner and policy committed,
exact retained plist/configuration, unchanged certificate/issuer and graph. Guarded
recover_owned_listener.py --start bootstrapped that original job once, verified live
owner-mode identity, republished the same instance/profile and saved active.json.
No owner registration, native provision, key creation or database restart repeated.
Helper inspect confirms active; private API live200/ready200/schema28clean/protected401.
Evidence: staging/selected-service-owner-20261022/listener-recovery-result.json and
installed-active-status.json. Original failures and one-time recovery markers retained.

Transfer Check setup status now visibly shows “DevGraph is ready to manage” and
“Owner registered”. Open Credentials & requests selected the actual local connection
https://127.0.0.1[local configuration]; its inbox awaits Transfer Wallet unlock. No browser handoff.

User clarification: Transfer is the native credential-management client. DevGraph's
independently running service owns the HTTPS listener/web/API transport. Transfer
uses a local connection to configure grants; it must not become the web host or
own public exposure. Current listener is a separate launchd service, loopback-only.
Closing Transfer does not define its service lifecycle. No new LAN/public exposure
or alternative IPC protocol is authorized/needed by this clarification.

Next: unlock Transfer only when ready, inspect actual owner inbox, then select real
recipient request and configure exact custom permissions/preset, hierarchy and duration.
Actual production member credential and iPad acceptance remain outstanding; do not
send another fixture18891 request or mark the credential-delivery MVP complete.

Latest recovery, 2026-10-22: an actual production owner preparation is retained,
but no owner registration or activation has committed. Build25 could not reopen
its review because Foundation sorted filename keys differently from DevGraph's
canonical JSON. Build26 fixes only that digest encoding, preserving all digest,
identity and selected-service checks. The actual retained review decodes correctly;
147 native tests executed, three optional skips, zero failures. Build26 is packaged
and signature-verified, awaiting opening approval. This does not activate authority.


Latest installed checkpoint, 2026-10-22: build25 now implements the guided native
owner flow for the exact launched Wallet instance. The resource detail has one
primary **Set up owner Wallet** action. Its native sheet walks through unlock,
default administrator review and registration, then **Open Credentials & requests**.
It has no owner permission/preset picker or alternate endpoint field. Production
registration has not been dispatched. Build25 was opened after approval and its
owner setup sheet was visually verified, with Unlock Wallet as the primary action.

The protected new local helper reuses the running service's certificate and issuer,
binds the native first-owner proof to its exact HTTPS endpoint, and retains the
original proof/phase markers for recovery. Explicit activation updates only that
selected launch job, preserving graph/instance IDs and existing agent authority.
The native policy review remains a final owner approval, not an implicit effect
of discovery or Wallet unlock. Historical owner plans and wire profiles remain
compatible. Backend62passed, final packaged owner5passed; native144executed with
three optional skips and zero failures. Code-only helper installation and its
read-only actual-service inspection passed; no owner, policy or listener changed.

The actual graph's unclaimed Wallet
service is running at `https://127.0.0.1[local configuration]`, instance
`3946a343-756c-5d71-afaf-7f4597e95e1a`. Exact-certificate HTTPS checks passed;
the service publishes its own `zenith.local-service.v1` discovery entry. Owner,
operator, member enrollment and Work execution remain closed (`owner_setup_required`).
The existing private API is healthy and its configuration, graph registration and
native policy hashes are unchanged. This is a Mac-only listener, not an iPad/LAN
connection. No owner, grant or global certificate trust was created.

Build24 was opened and visually verified. It labels this instance “Running ·
Owner registration required.” Installed build25 owner activation and subsequent
actual production grant/iPad acceptance remain unfinished.

| Component | Verified state | Remaining work |
| --- | --- | --- |
| Local resource discovery | Private API and running unclaimed Wallet service published as separate instances of the real graph | Select Wallet instance; retain exact identity and endpoint through ownership |
| Permission recipes | Native creator, immutable revisions, descriptive Seat-type references built | Custom server-catalog publication is separate from using local recipes |
| Native credential editor | Build16; independent action presets and global/multiple path selection; exact review and native Wallet boundary | Installed picker/review/issue qualification against the real graph |
| Grant protocol | Existing versioned review/approve/status flow; original-action journal; native fake-server activation/recovery tests | Actual production receipt/readback and retained-result recovery |
| Owner setup | Build25 guided same-instance unlock/review/register flow, protected local setup helper, signed owner claim, status recovery and native tests | Open/visually verify build25; approve actual owner registration and verify installed native inbox |
| Production HTTPS and operator admission | Loopback-only unclaimed service launched and certificate-verified; no owner/operator authority | Same-instance owner proof/activation, then real native operator/inbox acceptance |
| iPad | Existing isolated graph read/reuse proved earlier | Real connection, real request, exact native grant and scoped production use |
| Onward delegation | Unavailable; unknown authority fields fail closed | Keep disabled; future protocol work only |

Build16 source: `69c3e1f3b22ec25f185cab4d91ca029cf3d67a2c`.
Existing validation: 113 Swift tests executed, 110 passed and three optional tests
skipped. Four exact native selections match the existing JavaScript producer and
pass DevGraph's standing-grant decoder. Installed native inbox authentication
passed on the isolated server with no new grant. These are supporting checks,
not evidence of production activation or an installed production grant.

## Next implementation: production connection prerequisite

- Trace the installed host, native Wallet/secS companion versions and the source
  receiver's actual configuration/entry points. Record supported operations;
  don't infer compatibility from the editor compiling or a previous test package.
- Implement owner-controlled local **prepare / install / status** from the
  reviewed configuration. Recheck resource/configuration fingerprints, owner
  identity proof, current hierarchy and every authority precondition. A public
  key or portable plan by itself must never authorize installation.
- Stage an immutable matched receiver and production-only TLS/read-issuer
  configuration. Preserve the existing graph, receipt/replay history, existing
  signer and managed agent policy. Do not copy fixture secrets, grant stores,
  synthetic data or test identities into production.
- Keep the private API and database loopback-only. Any separately proposed
  HTTPS/LAN endpoint needs its exact address, certificate and exposure reviewed.
  Produce a concrete public diff and recovery record before activation.
- Operator admission and member execution admission are distinct. Verify that the
  native signer/receiver can admit the exact member's selected operations without
  erasing existing agent rights or relying on the fixture's static Wallet list.
  Show unsupported execution rights as unavailable rather than issuing a grant
  that cannot execute.
- Record durable cutover phases. If an outcome is uncertain, inspect/reconcile the
  same run; do not create new keys, replace authority, reset replay or blindly
  retry. Rollback must not undo a committed grant or resurrect expired access.
- After exact approval, activate and verify the real endpoint. Publish its public
  connection under the existing `.zenith` resource identity. Transfer must then
  enter the same native credential editor directly; no browser handoff or second
  owner-configuration pass during each grant.

Owner setup UI must remain clearly separate from a member credential editor.
Advanced server grant policy is not a second member permission envelope. Do not
turn this prerequisite into another UI-only completion milestone.

## Required production acceptance

The exact recipient and resources will be selected in Transfer before any real
member grant. Use an operator-approved scope and reversible operation for the
write proof; don't create or mutate real work merely to demonstrate controls.

- [ ] Real endpoint identifies the expected resource, issuer and owner; certificate
      validation and pinned-origin binding pass. Anonymous/protected routes stay
      closed; the private API/database are not exposed by the connection setup.
- [ ] Owner admission authenticates the intended Wallet; another Wallet cannot
      list requests, issue/revoke grants or replace owner configuration.
- [ ] Real request appears in native Transfer and the hierarchy comes from the
      real graph, with human names and stable typed IDs.
- [ ] Preset and scope are independent. One branch, multiple branches and explicit
      global scope compile to the reviewed exact selection; policy limits remain
      correlated. No silent permission or scope expansion occurs.
- [ ] Exact native review/activation/readback succeeds. Changing read alone does
      not falsely imply revocation of existing writes, or vice versa.
- [ ] The iPad redeems the real standing grant, loads included work/details and
      reuses access across navigation without another operator decision.
- [ ] Authorized write reaches native secS and DevGraph and has the matching
      committed Work/EventReceipt evidence. Unsupported operations stay absent.
- [ ] Excluded siblings/relationship endpoints and moved-out objects are denied;
      newly contained work is admitted only according to the actual path rules.
- [ ] Short credential expiry can be renewed under a valid standing grant; grant
      expiry/revocation rejects retained access. Onward delegation cannot be enabled.
- [ ] Lock, restart and response loss retain the exact original decision and
      recover its status without a duplicate grant or Work mutation.
- [ ] DevGraph records the actual evidence and remaining limitations. Mark the
      work complete only after the real user journey passes.

Current limitation: path grants cannot create unattached Work; the editor removes
that operation and explains it. Issue/Task leaf picking and direct editing of an
existing grant without a member request are not claimed by build16. Track any
required additions explicitly instead of disguising them as completed controls.

## Build17 production bridge candidate (2026-10-22)

The actual resource remains unconfigured for HTTPS until explicit approval. The
proposed LAN connection is `https://[local configuration]:18443`; port18891 remains the
isolated graph and is not the delivery target. Owner setup stages an exact
installation review and records activation phases. Recipients no longer need a
static native allowlist in setup: opt-in runtime v9 admits the selected holder
and operations only during the final authenticated credential decision, while
the guarded receiver still enforces the actual path and assignment. Historical
finite agent rules, signing key/deadline, private API, canonical graph and replay
state must be preserved. A partial external native update cannot commit a member
assignment and requires inspection. Until-revoked member validity does not renew
the separately expiring service key.

Do not mark the journey complete from the build or source tests. Production
setup, exact owner Wallet proof, a real request/custom credential and the iPad
acceptance checks above remain required.

## Owner registration simplification (2026-10-22, build18)

The owner does not issue themselves a member credential or select a preset,
resource scope or maximum grant duration. Owner registration defaults to managing
all supported credentials across the graph until revoked. Local filesystem
ownership of the actual configured installation permits initial key binding;
being on the same network or merely discovering a service does not. An already
configured endpoint cannot be silently claimed or overwritten. Subsequent
requests authenticate the configured owner through native Wallet signatures.
Member credentials still use the complete independent custom/preset and hierarchy
editor, and onward delegation remains disabled.

The current setup plan is not a Wallet-signed ownership certificate. Do not label
it “signed by owner.” An independently verifiable ownership declaration needs a
dedicated domain-separated Wallet claim binding the resource UUID, current local
configuration/registration and setup review, with an explicit first-owner CAS;
replacement requires the existing owner or an explicit local recovery ceremony.
This remains a distinct proof-format requirement, not a reason to ask the owner
to grant themselves a member credential. Installed production activation and
first signed native administration are still acceptance gates.

## Bounded permission clarity improvement (build19)

The native preset and individual credential editors now name the existing read
actions as Work list, Work details and Work relationships, with scope-aware
descriptions. They explicitly disclose that Arena-record reads are unavailable
in the current credential format. Selecting an Arena as a resource boundary is
not an Arena-read permission. This is a presentation correction, not new
authority, a schema expansion or a completed credential ontology. The canonical
Zenith credential-system design/review is tracked separately in DevGraph.

## Selected-connection correction (2026-10-22, build20)

Owner registration must inherit the selected resource ID and exact connection.
The automatically suggested LAN listener and editable endpoint are removed. A
retained plan for another endpoint cannot be saved, prepared or activated through
this flow. Historical plans remain readable as evidence; they are not silently
retargeted. The configured private API at http://127.0.0.1:8080 currently lacks
Wallet administration routes and the native credential transport requires HTTPS.
Registration therefore reports the installed-server upgrade prerequisite instead
of requesting another Wallet unlock and proposing a new port.

Next backend work is the reviewed upgrade of the selected service/connection,
with a compatible local administration transport, preserved identity/auth/audit/
replay behavior and matching Wallet verification. A separate guessed listener is
not an acceptable substitute. Do not change the selected connection or weaken
HTTPS verification to make registration appear to work. No production owner or
member authority has been installed by this correction.

## Chooser-to-connection handoff (build21)

The chooser uses distinct local-resource and saved-connection selections. Opening
owner setup or access management captures that exact selected value; the second
screen does not resolve a different current/default resource. Missing or ambiguous
selections do not fall back. The native screen identity includes the selected
address and public verification settings so a changed issuer/pin cannot inherit
another connection's StateObject/client. The local installation inspector also
checks the fixed CLI's reported actual base URL against the selected registry
record, instead of assuming port8080.

Regression evidence: 17 targeted tests passed, one optional installed smoke skipped.
Tests cover two different local addresses, two saved remote origins/issuers, actual
mocked native challenge request destinations, missing/ambiguous selections and
view identity after a verification-pin change. These prove connection routing;
they do not establish production owner registration or an installed grant. The
legacy v1/v2 installer plan remains a separate narrow contract and cannot be
reused to redirect this selected-connection flow to a proposed second listener.

## First-owner bootstrap implementation (source only, 2026-10-22)

The next backend contract is implemented as an internal, one-time bootstrap,
separate from the historical listener installer. The exact selected resource UUID,
endpoint and configuration/registration digests are bound into a dedicated
Wallet-signed owner claim. A protected local adapter must arm a 256-bit setup
authorization; only its digest is retained in the bootstrap state. Successful
redemption records the first administrator grant and consumes setup authorization
in one SQLite transaction. An exact original proof recovers the retained result
after response loss; it never issues a second administrator grant.

The administrator grant lasts until revoked and has only the existing credential
administration operation family. Its two-minute review challenge is not the grant
lifetime. Explicitly refreshing a review does not extend the setup deadline or
change the selected Wallet/grant. Onward delegation and child administrator grants
are unsupported. Future admin attenuation belongs to the separately tracked
credential ontology/schema work.

Castalia exposes an optional native owner-review capability and separate prepare/
approve commands. Existing custody snapshots and membership bytes are unchanged.
Transfer independently checks the native review and returned signature; a core
without the new capability fails with an update-required error. A shared public
synthetic signing vector binds Python, Rust and Swift verification to identical
bytes. Target/configuration drift, additional authority, wrong Wallet, expiry,
replay and interrupted commit are covered by the focused tests.

This is **not installed activation**. Build21 remains the visible preview, and
its selected private API remains http://127.0.0.1:8080. No setup authorization,
owner claim, admin grant, listener, certificate or production policy has been
created by this source work. Existing agent access remains intact. Remaining:

1. Wire the protected owner-local adapter and owner-backed operator verifier into
   the selected real resource; never infer an unowned installation from a missing
   file or from being on the same network.
2. Package the matching native core/runtime, preserving existing installed state,
   and review the exact first-owner activation before any authority change.
3. Connect Transfer's native owner review to that adapter, then verify actual
   authenticated inbox/custom credential issuance against the real graph.
4. Review a real member connection separately where LAN/remote transport is
   required, then finish iPad read/write/scope/reuse/revocation acceptance.

The old v1/v2 installer cannot substitute a guessed HTTPS listener for the
selected private API. Health and discovery may remain available before bootstrap;
the new admin/member surfaces must fail closed until explicit owner setup.

## Selected graph Wallet admin upgrade (build 22 candidate)

The protected local adapter and owner-backed runtime verification are now implemented.
Transfer keeps the selected resource UUID, source URL, data root and configuration
fingerprints. A v3 upgrade explicitly proposes an OS-selected loopback HTTPS port
for that same graph, alongside its existing private HTTP API. This is not a redirect
to the old fixture or an implicit LAN listener. The exact channel, pinned certificate,
owner key, retained native rules and service-key deadline are reviewed together.

The fixed per-user helper has propose/prepare/claim-prepare/claim-refresh/claim-complete/
claim-status/activate/status operations. Setup authorization stays in a separate
short-lived local handle protected by directory0700/file0600; only its digest is
stored in the server bootstrap state. The handle is removed after consumption.
The owner signs a domain-separated claim whose grant ID is the canonical upgrade
review digest. Runtime administration re-verifies that owner signature and exact
operator policy. Legacy unsigned v1/v2 activation is rejected; persisted plans
remain readable for inspection. No owner attenuation is included.

Transfer retains the original signed proof before possible dispatch. Status recovery
reads that proof without signing or redeeming again. Partial activation never
automatically retries native provisioning. The owner is an administrator until
revoked; two-minute consent and fifteen-minute local setup timers are separate.

Validation: full native suite132executed/3optional skips/0failures; new packaged-core
owner signing/one-shot/lock integration passed separately. Focused backend52passed,
including one-time consumption, exact review binding, original-proof recovery,
owner/policy tampering and localhost boundary checks. Earlier affected runtime
regressions78passed. These are source/package checks, not installed acceptance.

The matching code-only helper is installed as immutable release
1a200cf29ebf36e6e49727d14ae3f57a2cd1eaf71ba21775c68c3744eb63889e;
its help and read-only selected-graph proposal checks passed. No setup authorization,
owner claim, policy change or listener has been activated.

Still required: review/open build22, prepare the exact
production upgrade in Transfer, obtain the exact owner/upgrade approval and Wallet
signature, then verify the authenticated native inbox/custom credential issuance.
LAN/iPad transport and real member read/write/scope/reuse/revocation remain separate
acceptance gates. No production ownership or new listener is claimed active.

## Discovery and selected-instance correction (build23)

User clarified the chooser must discover launched interfaces and provision the exact
selected one. A graph ID is now distinct from a service instance ID. The additive
public registry ~/.zenith/services/v1 identifies private-api and wallet-api
interfaces independently, retaining the graph association. Wallet listener publication
does not overwrite the original private API registration. Existing resource records
and saved connection bytes remain readable. Registry timestamps are not liveness.

Transfer performs fresh bounded credential-free metadata checks. Wallet management
requires matching graph/instance IDs, runtime capability mode, receiver, issuer and
authority pin. Stopped or mismatched services stay unavailable. A private API has no
Connect owner Wallet action and cannot open the historical proposed-channel upgrade.
Selections are explicit; no first-item fallback occurs. Each launched Wallet service
keeps its exact connection through native grant management. No browser handoff.

Validation: full native139executed/3optional skipped/0failed, final discovery/selection
8passed; producer61passed including multiple interfaces, preserved original API
registration, changed-registration rejection and metadata-only refresh. Ruff checks
passed for changed producer files. Build23 packaged/signed and opened after explicit approval. Installed native UI
and screenshot confirm actual private API8080 is running, preserves its exact
selection, and has no alternate-endpoint owner setup action. Wallet stayed locked;
no production authority was activated.

Remaining first-owner gate: explicitly launch an unclaimed Wallet service, publish
its instance, select it, then perform same-endpoint local ownership registration. The
previous combined v3 private-API-selected upgrade remains historical source and is
removed from the chooser. This discovery change does not launch that production
service or register its owner. Production-native custom grant and iPad acceptance
remain incomplete; onward delegation/attenuation remain deferred.
