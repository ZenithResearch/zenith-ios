# Transfer credential-setting completion plan

Reviewed against source and installed state on 2026-10-22. This supersedes the
older build14 completion checklist in the execution evidence. The deliverable is
an operator using the native Transfer application to configure and issue access
to the actual configured DevGraph. Completing fixture tests, an owner form or a
saved setup plan does not complete that deliverable.

## Main user journey

1. Select **DevGraph on this Mac**, stable resource
   `f378a8ef-95ab-409a-9996-d43163df41fb`. Its private API is
   `http://127.0.0.1:8080`. Register and verify its actual HTTPS Wallet connection.
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

| Component | Verified state | Remaining work |
| --- | --- | --- |
| Local resource discovery | Real UUID/private API selected; registry reader exists | Publish the real HTTPS connection after activation; preserve UUID |
| Permission recipes | Native creator, immutable revisions, descriptive Seat-type references built | Custom server-catalog publication is separate from using local recipes |
| Native credential editor | Build16; independent action presets and global/multiple path selection; exact review and native Wallet boundary | Installed picker/review/issue qualification against the real graph |
| Grant protocol | Existing versioned review/approve/status flow; original-action journal; native fake-server activation/recovery tests | Actual production receipt/readback and retained-result recovery |
| Owner setup | Native form, strict v1/v2 saved-plan contracts and pure policy compiler | Actual prepare/install/status boundary and installed ownership proof |
| Production HTTPS and operator admission | Not active from these plans | Reviewed matched source, certificate/issuer, operator admission, service activation and connection publication |
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
