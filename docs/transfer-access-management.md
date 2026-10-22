# Access management in Transfer

Transfer is the operator application. Register a resource from its public HTTPS connection settings, open **Manage access in Transfer**, and unlock the app's Castalia Wallet in that screen. Review requests, choose a permission preset independently of its resource paths, review the exact selection, and approve its signed decision. Grant inspection and revocation use the same native flow. The resource must already admit that Wallet as an operator.

Build16 renders the request inbox, credential editor, resource hierarchy and exact-selection review in SwiftUI. It is separate from owner setup and does not open a WKWebView or external monitor. The existing native boundary validates the selected resource, issuer, challenge, policy revision and exact action before presenting Castalia consent. Signing stays in the shared Wallet core; the editor receives no private key. Native HTTPS transport sends the approved proof to that resource's challenge/action endpoints. A durable action journal requires recovery of the original decision after an uncertain dispatch.

Each resource owns its operator policy and activates its grants. DevGraph's current operator interface uses Wallet public keys for admission, its own access policy/inbox, and the existing secS-backed credential path. A separate central authentication/settings server is not required for this implementation. Other resource types need an explicit compatible management contract; a registered port alone does not make a service administrable.

Transfer's main resource flow does not launch an external browser or redirect to a legacy monitor. A locally discovered service without published HTTPS Wallet settings asks for a public connection file. The operator interface is not an owner-bootstrap bypass: discovery, registration and Wallet import do not add operator authority. The primary DevGraph's owner setup and HTTPS publication remain separate from the retained isolated LAN deployment.

The installed build10 test authenticated the actual Transfer Wallet against the isolated LAN inbox. Build12 subsequently completed the exact approved iPad replacement through native consent and pinned HTTPS, activated the paired standing read/write grant once, and read it back from the inbox. The user confirmed the iPad redeemed its read credential and loaded the included-only work. This was the isolated synthetic graph on port18891; it does not prove production activation or native write execution. Deliberately induced uncertain installed-decision recovery remains a separate qualification check.

Build11 removed the external-browser handoffs and authenticated the retained native inbox. Its installed check exposed a stale editor identity when opening management while locked and unlocking inside its sheet. Build12 refreshes that identity on native Wallet state changes; it never reloads or replaces a pending decision. The WKWebView regression starts locked, unlocks without reopening, and verifies that lock/unlock preserves the original uncertain-action journal before recovery. The installed build12 check then verified unlock refresh and the subsequent paired grant activation described above.


## Local owner setup editor

On this Mac → DevGraph → **Set up owner & access** opens the native owner editor.
It checks the actual configured resource and reads real Arena/Initiative/Project
pages through the fixed installed DevGraph CLI. Select the proposed owner Wallet,
permissions it may grant, explicit global or multiple inherited path scopes,
duration, a separate HTTPS address, and public hierarchy visibility. Review and
save the exact setup plan. Password entry stays in the native Wallet sheet.

This first owner setup build saves `prepared_not_applied` plans; it does not
activate an owner, create a member grant, start HTTPS, or alter the production
registry. The production activation installer is the next gate after the chosen
configuration is reviewed. An imported Wallet, local registration and the saved
plan confer no administration by themselves. Existing test grants remain test
grants. Legacy plans use `zenith.devgraph-owner-setup.v1`; the native preset editor uses the explicit v2 contract below.

## Native permission recipes and seats

Build14 adds **Credential presets** to Transfer's native sidebar. Create a recipe
from Read only, Contributor or Project Manager; choose read/write operations;
review and save a revision. Duplicate built-ins, revise custom recipes, and
archive/restore recipes without changing previously issued access. Saved recipes
are reusable in the native **Set up owner & access** editor, where resource scope
and duration remain separate. A reviewed setup embeds the exact recipe revision
and operations, even if that recipe changes later.

Optional Seat associations use the shared Zenith Seat class. A Seat is a position
in an organization that a Person or Agent may fill. A SeatType classifies such
positions; SeatAssignment describes the occupant and effective period. The native
editor can reuse a saved SeatType reference or create a local reference URN. It
stores descriptive metadata, not a directory appointment or verified external
SeatType record. The source ontology v0.10.0 adds the shared vocabulary without
new runtime Work kinds, storage migrations or implicit credentials.

Owner setup v2 makes granular read operations explicit and snapshots the recipe.
The v1 parser/digests stay compatible. Custom recipes remain local until a future
reviewed server catalog publication. Saving a recipe or owner plan creates no
member grants and does not activate the production owner. Build16 also uses the recipes in its native per-request credential editor. Production
owner installation remains a separate unfinished gate.

## Native per-request credential editor (build16)

Open a saved HTTPS resource → **Manage access in Transfer** → **Review inbox in
Wallet**. Select a request and choose a server preset, local recipe or custom
permissions. Permission presets select actions; they do not select an Arena or
expand the resource scope. Unavailable recipe actions are removed with a visible
notice. Local recipes are not silently published to the server catalog.

Choose one or more named Arena/Initiative/Project branches in the hierarchy, or
explicitly choose all resources permitted by the server. Selecting a container
includes matching descendants at the time of access; moving out removes access.
A selected parent visually includes its children. Empty selection, missing
hierarchy data or an out-of-policy path never falls back to global access. The
exact review retains each server rule’s correlated kind, object, Arena and path
restrictions. Creating unattached Work is unavailable for a path grant.

Choose until-revoked validity when allowed, or a dated expiry within policy.
Review the exact read/write snapshot, then separately confirm activation in
Castalia. Read remains installation-bound; writes follow the Wallet across
admitted installations. Changing read alone preserves any existing write grant,
and vice versa. No separate delegation ceiling is configured here.

**Onward delegation is not allowed.** Current grants cannot issue child
credentials; there is no enable switch. Future authority/delegation fields and
unsupported operations fail closed rather than being cloned into a credential.
Seat metadata remains descriptive and does not confer permissions.

Lock, closure or lost responses preserve the original action journal. Recover
its status before preparing another decision. The Swift editor uses the existing
versioned challenge/action contracts; older pending records and the retained
bundled-renderer regression path remain compatible.

Validation: native selection vectors match the established JavaScript producer
and are accepted by DevGraph’s standing-grant receiver decoder. Disposable
Wallet/fake-server tests cover inbox → review → activation, retained-journal
lock/relaunch and status-only recovery without replay, concurrent preparation,
and tampered challenges. Installed UI and production activation are distinct
qualification gates; source tests do not establish production access.
