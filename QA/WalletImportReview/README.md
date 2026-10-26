# Wallet import review QA

This isolated iOS/macOS app renders the production shared review component with
public synthetic fixtures. It never opens a Wallet database, imports a backup,
uses a real password, grants access or contacts a server. The confirmation button
is intentionally inert; transaction behavior is covered by real-core package tests.

Generate with `xcodegen generate --spec QA/WalletImportReview/project.yml`.
Build/test the WalletReviewQA scheme for Simulator, or build WalletReviewMacQA
for macOS. Use WALLET_REVIEW_SCENARIO=recovery, combined, data, legacy or empty;
WALLET_REVIEW_LARGE_TEXT=1 enables accessibility text. The UI tests expand
sections, capture screenshots and dismiss a review. Obtain approval for that
interaction when required by the machine's QA policy.
