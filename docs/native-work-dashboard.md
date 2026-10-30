# Native Work page

The Work tab contains Project Pulse, Activity and Todo on one native page.
iPhone stacks one-item previews with section jump links, an inline navigation
title, and See all navigation. iPad shows two-item previews.
At widths of 760 points or more, two aligned rows use an approximately 62/38
primary/sidebar split: Pulse beside Activity, then Notepad beside Todo. Each row
shares a measured height; headers, context tracks, padding and footer baselines
align. The secondary track stays at least 300 points where space permits, so
readability takes precedence over an exact ratio. Large accessibility text
returns to the single-column layout. System grouped surfaces,
Dynamic Type, segmented pickers, NavigationStack, and searchable expanded lists
follow the existing iOS app. There is no personal-focus mode or project icon.
The wide layout omits redundant section-jump navigation. Compact context cards,
subtle panel separators and selected-context counts keep the hierarchy readable.
Status dots supplement explicit text, never replace it. Project rows show Arena
context and separate Doing/Done task previews; issue counts stay secondary.
The notepad editor has a quiet inset surface using native semantic colors.

Arenas and Initiatives are context filters above the permanent project list.
Projects rank by the latest valid update in the project or its loaded descendants.
Activity previews Issues, with a separate project filter. Todo remains independently
ordered by recorded priority and includes only not-started Tasks. Opening a Work
record uses the existing authorized detail reader. Loaded children are shown before
a collapsible description. Notepad is the Capture surface. The toolbar action
scrolls to and focuses its multiline editor; Save note clears the editor and makes
the text readable in Saved notes. Filters and source navigation preserve the draft
while this page remains open. Notes are explicitly in page memory, not persistent
storage or a Work write. iPhone places the notepad after Todo. A separate All shared
work list keeps other permitted Work kinds reachable.

The loader preserves the current Wallet-approved read client and its permission,
expiry, lifecycle and private-network checks. All graph state is read through the
existing SDK. Arena membership is loaded only under explicit Arena get permission.
WorkDashboardReader automatically follows pages for every Work kind included in the approved list grants (including Proposal and Todo where shared). It reads Arena members and explicit children/parent relationships separately: per-operation list grants may intentionally omit parent edges. WorkDashboard retains those witnessed edges independently of list-summary fields. Explicit Arena get grants also work without collection-list authority. Pagination and hierarchy reads have a request budget; reaching it retains partial data and offers Continue loading. Counts and order describe loaded items. Unshared or
unfinished membership is not inferred from project titles or working directories.

## Additive consumer compatibility

`WorkRecord` now reads the optional `parent` and `updated_at` fields already emitted
by canonical `todo_summary` (`devgraph.todos.v2`). Legacy native-v2 summaries that
omit them still decode. Unknown or invalid dates cannot imply freshness; malformed
parent keys fail closed. This is an additive consumer change with no producer,
permission schema, credential, persisted request, or service deployment change.

## Capability limits

The native v2–v6 read protocols list Work and Arena resources, but do not expose
session-ref reads or session-state writes. The Sessions option is deferred and hidden; Activity shows Issues. It does not call the prototype's private loopback companion or present record timestamps as session activity. Native session capabilities are tracked as Project/devgraph-native-session-pulse under Initiative/devgraph-runtime-integrations. The future deployment must package the DevGraph API and required observation/source-resolution dependencies through the lightweight Hub; Hub remains the deployer rather than the canonical Work service. That work needs a separately coordinated producer/permission/client change; existing grants
are never expanded by this UI.

The native read projection also supplies no compatible versioned complexity
estimates. Project complexity therefore remains Unestimated, without a guessed
percentage, completion bar, or velocity. Recorded Task Done does not imply accepted
delivery. The isolated QA app verifies presentation with synthetic data; it does
not demonstrate live server or session connectivity.

## Future user-created views

Work remains SwiftUI for this delivery. The proposed embedded HTML/CSS,
TypeScript and Rust/WASM view runtime is deferred as Project/blank-dashboard,
under Initiative/zenith-app-experience (iOS App) in Arena/zenith (Zenith).
Its purpose is to let users compose or author their own views. Wallet screens,
custody and approval remain native. No embedded runtime, plugin loader or new
bridge is introduced by the Work dashboard.
