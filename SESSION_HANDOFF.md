# Session Handoff — SaneClick

**Last updated:** 2026-07-28
**Current public version:** `1.3.1` (build `1301`)
**Release candidate:** `1.3.2` (build `1302`)
**Audited commit:** `b5fc2a952c202348e10f5816c8eac5c16f0b8711`

## Active Release State

SaneClick direct downloads now use one customer path: a free 14-day trial with every feature, followed by a $14.99 one-time purchase. Retired Basic/Pro tier wording does not apply to the direct release. App Store product identifiers that contain `pro` are internal and belong to the separate App Store lane.

Public release note:

> Improves fresh-install Finder setup and custom action editing. Also polishes setup, purchase, and update screens.

### Current Mini receipts

- 188 tests in 22 suites passed. Log: `outputs/verify/20260728T173755.694477Z-7777-691dfeca/01-test.log`.
- Customer UI contract passed with all eight release actions covered: `03b0e58354c8e9e4c9060ae30732d8fe`.
- Signed Release launch log: `outputs/runtime/saneclick-1.3.2-live.log`.
- Fresh direct-install Settings proof: `outputs/customer-ui/settings-fresh-direct-monitored-folders.png`.
- Signed-release Finder action produced a timestamped duplicate: `outputs/e2e/1.3.2/SaneClick-E2E-132_20260728_140633.txt`.
- Finder action log: `outputs/runtime/finder-e2e-1.3.2.log`.

The customer UI sweep receipt above established source and contract coverage. It did not execute every manifest click or Finder action. `scripts/customer_ui_action_sweep.rb` now writes contract-only receipts unless a separate Mini runner supplies action-level execution evidence.

Expected pre-publish warnings: public appcast and Homebrew remain on 1.3.1 until release, unrelated pending support email exists, and the audit ran in the evening.

## Current Visual Proof

- Expired trial gate: `outputs/visual-audit-trial-expired/1.3.2/saneclick-expired-trial-1499.png`
- Final onboarding trial page: `outputs/visual-audit-onboarding/1.3.2/saneclick-trial-final-1499.png`
- Continue Trial result: `outputs/visual-audit-trial-active/1.3.2/saneclick-main-after-continue-trial.png`
- License settings: `outputs/visual-audit-trial-active/1.3.2/saneclick-license-settings-1499.png`
- Active main window: `outputs/customer-ui/content-all-actions.png`
- Active Script Library with all 62 actions enabled: `outputs/customer-ui/library-all-actions.png`
- Fresh direct Settings with five monitored folders: `outputs/customer-ui/settings-fresh-direct-monitored-folders.png`
- Finder result after the real Duplicate with Timestamp action: `outputs/e2e/1.3.2/finder-duplicate-result.png`

`outputs/visual-audit-trial-expired/1.3.2/saneclick-expired-trial.png` shows the old $9.99 price and is invalid. Do not use it as proof or publish it.

The Finder demo and pitch videos were frame-inspected on the Mini on 2026-07-28. They show the real Finder action, the 14-day full trial, the $14.99 one-time price, and no retired Basic/Pro customer copy. The website main-window and Script Library screenshots now use the fresh active 1.3.2 captures above.

## Remaining Release Work

1. Commit and push the verified 1.3.2 candidate.
2. Run the guarded release and App Store preflights on the clean commit.
3. Publish 1.3.2, then verify the appcast, Homebrew cask, website, checkout, and hosted download.

## Archive

- Direct 1.3.1 is the current public release.
- Direct 1.3.0 unified image handling on the native non-destructive path.
- App Store work remains a separate owner-gated lane.
