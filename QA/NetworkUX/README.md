# Native network UX benchmarks

This simulator-only app compiles the production `PrivateNetworkRow` and real
`PrivateNetworkSession` against an actor-based synthetic driver. It has its own
bundle ID (`ca.zenith.preview.network-ux`). It never instantiates WalletModel,
TailscaleDriver, Wallet Core, a signer, or a real private transport. Configuration
requests fail closed. It cannot enroll a real device or approve Work access.
Generated Xcode projects and build products are excluded from publication.

## Reproduce

From the iOS repository root, generate with
`xcodegen generate --spec QA/NetworkUX/project.yml`, then build the NetworkUX
scheme for an explicit existing simulator destination. Use an isolated derived
Data directory; do not reset existing simulator apps or data. Install and launch
only the review bundle. Select a scenario and exercise the native controls.
`NETWORK_UX_SCENARIO` can select `new`, `saved`, `approval`, `reauth`, or `storage`.
`NETWORK_UX_LARGE_TEXT=1` renders the review root at accessibility5; this is a
layout fixture, not a substitute for testing system Dynamic Type and VoiceOver.
The only accepted input used during review was a visibly synthetic auth key.
No real enrollment key, device state, Wallet or production grant is needed.

## User stories and observable acceptance criteria

| Story | Benchmark | Evidence from this review |
|---|---|---|
| I received an enrollment key. | Mask input, show a primary auth-key action, return to connected after enrollment, never open browser fallback. | iPhone native form, invalid input then synthetic success; model regressions. |
| I pasted the wrong key. | Clear submitted input, show safe actionable feedback, allow corrected input, never display upstream secrets. | iPhone interaction and model tests. |
| My administrator must approve this device. | Name the next actor, keep checking, allow leaving the sheet without cancelling, retain the saved device identity. | iPad enrollment → Keep waiting → synthetic approval → connected. |
| Approval takes longer than five minutes. | Do not ask for a consumed key; allow startup time after approval. | Model clock advanced ten minutes, then Starting → Running with one enrollment. |
| I return to Zenith. | Use saved device identity, no new enrollment request or automatic browser. | Cold-launch, migration and foreground model tests; saved scenario in both simulators. |
| My network temporarily drops. | Immediately invalidate old transports, keep polling, recover without another key. | iPhone reproduced prior stuck state; fixed Starting → Running interaction plus regression. |
| I explicitly disconnect. | Stay disconnected across foreground/relaunch until Reconnect; keep Wallet and server data. | iPhone Disconnect UI; persisted preference/model tests. |
| I disable automatic reconnect. | Remain offline automatically; explicit Reconnect or saved-state retry still works. | Model tests; native preference control inspected. |
| My device sign-in expires. | Explain renewal, offer explicit repair, do not launch a browser automatically. | iPad renewal UI; interactive-intent regression. |
| Saved device state is temporarily unreadable. | Offer a working Retry saved connection rather than forcing fresh enrollment. | iPad protected-storage failure → retry → connected; cancellation-race regression. |
| I use larger text or assistive technology. | Wrap content, retain individually named actions and reachable exits; announce async outcomes once. | iPhone accessibility5 root and AX inspection; full VoiceOver/system-size/split-view qualification remains open. |
| I need my Work server. | Distinguish private network, server reachability and Work authorization; network success must not imply a Work grant. | Copy/source review only; live server/request/grant/load walkthrough remains open. |

## Roundtable outcome, 2026-10-25

Three independent reviews covered user stories, interaction design, and lifecycle
state. The simulator reproduced the highest-priority defect: Running → Starting
ended polling, left only Cancel, and could never observe Running again. The fix
continues polling while cancelling stale transports. Follow-up review added
regressions for consumed interactive sign-in intent, delayed approval startup,
and Disconnect during saved-state retry.

Focused UI changes: emphasize Reconnect; collapse alternate authentication;
provide Retry saved connection; explain sign-in renewal; reflect live state in
Manage; use a full-height management sheet; add Keep waiting; focus enrollment
errors; ignore file-picker cancellation. Stored preferences and device state
formats are unchanged. The shared session and its tests remain identical in
Zenith Transfer; Transfer's running app was not replaced.

Remaining design work:

1. Let users choose a saved server/file before transport setup. A server profile
   should determine whether its private network is needed.
2. Decide how network preparation is reached before Wallet onboarding. Current
   RootView hides Work/Settings until custody setup and backup verification.
3. Reduce enrollment guidance density and give approval a dedicated compact
   progress view instead of retaining the entire key form.
4. Qualify system Dynamic Type, VoiceOver announcements, smallest phone and iPad
   split view. Fixture-level accessibility checks are partial evidence.
5. Complete a live network → server → request → grant → Work load walkthrough.
   Synthetic UI review is not evidence of backend authorization or device VPN
   behavior. This release still uses an app-scoped foreground connection.

No production service, exposure, credential, Wallet, or physical-device app was
changed by this review.
