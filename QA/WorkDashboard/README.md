# Native Work dashboard review

This isolated app renders the **same `App/WorkDashboardView.swift` used by the
Wallet-authenticated Work tab**. Its small synthetic Work graph is labeled in
the UI. It cannot connect a server, open a Wallet, sign a request or mutate Work.
It uses its own bundle identifier, so installing it preserves the real app.

Generate with `xcodegen generate --spec QA/WorkDashboard/project.yml`, then build
the `WorkDashboardReview` scheme for iOS Simulator. Reuse the repository's stable
simulator DerivedData. Set `WORK_REVIEW_LARGE_TEXT=1` at launch to review
accessibility-size text. Do not use this harness as evidence of live credentials,
session loading, or production authorization.

Verify phone/iPad overview, jump links, Arena/Initiative filtering, independent
Todo priority order, expanded lists and search, source navigation and Back.


The proportional layout also checks aligned panel rows in iPad portrait/landscape,
and the shared notepad Capture flow: toolbar focus, multiline editing, save and
saved-note readback. The review app uses the same bound notepad state interface as
the real Work tab. Notes remain page-local and cannot create a canonical Task.
