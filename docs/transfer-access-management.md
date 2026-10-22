# Access management in Transfer

Transfer is the operator application. Register a resource from its public HTTPS connection settings, open **Manage access in Transfer**, and unlock the app's Castalia Wallet in that screen. Review requests, choose a permission preset independently of its resource paths, review the exact selection, and approve its signed decision. Grant inspection and revocation use the same native flow. The resource must already admit that Wallet as an operator.

The management UI is bundled with the signed application and rendered inside its WKWebView. It is not a remote monitor page. Its native bridge validates the selected resource, issuer, challenge, policy revision and exact action before presenting Castalia consent. Signing stays in the shared Wallet core; the key is not given to the renderer. Native HTTPS transport sends the approved proof to that resource's challenge/action endpoints. A durable action journal requires recovery of the original decision after an uncertain dispatch.

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
member grants and does not activate the production owner. The existing signed
operator execution is still the bundled native-transport/WKWebView flow; replacing
its grant selection screen with the Swift editor and connecting production owner
installation are tracked next steps, not completed by this UI build.
