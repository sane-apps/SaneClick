# Session Handoff — SaneClick

**Last updated:** 2026-08-18 18:23 EDT

## 2026-08-18 18:23 — 1.3.3 ready to publish

Air customer-UI 8-action receipt passed (`outputs/customer-ui/sweep-20260818T221453Z/`).
Finder host execution created `saneclick-proof_20260818_181326.txt`.
`release_preflight` green (193 tests). Sparkle/Homebrew still on 1.3.2 until
`release.sh --full --deploy`. LS ZIP goes in `~/Desktop/LemonSqueezy-Uploads`.

Trial model: 14 days of every Finder action, then a hard buy gate. No leftover
Basic set after expiry.

## 2026-08-17 23:15 — 2am publish scheduled

One-shot Grok task `SaneApps 2am publish` fires 2026-08-18 02:00 ET.
Brief: `~/SaneApps/outputs/release-2am-2026-08-18.md`. Action 7 Finder proof
already passed (`outputs/e2e/1.3.3-20260818T025902Z/`). Still need the 8-action
runtime sweep + preflight before publishing 1.3.3. Do not start while the
owner is on Mini.

## 2026-08-14 22:30 EDT

## 2026-08-14 Action 7

Installed `/Applications/SaneClick.app` is **1.3.3 (1303)**. A real Finder
right-click on `Downloads/saneclick-proof.txt` opened the SaneClick menu
(Essentials, Files & Folders, Coding, Advanced, Open SaneClick). Extension
log: `menu(for:)` fired. Evidence:
`outputs/e2e/1.3.3-20260815T020349Z/finder-menu-open.png`.

The click never produced a timestamped copy. Two blockers:

1. The installed app was on the expired-trial gate. That window never mounts
   `ContentView`, so `ScriptStore` stayed empty and host execution could not
   find Duplicate with Timestamp.
2. AX still cannot see Finder context-menu items. Pixel/type-select did not
   land on Duplicate.

Source fix on this checkout (not in the installed 1.3.3): load
`ScriptStore` at app launch and again before Finder execution. Canonical Mini
verify passed **191 tests**, receipt `8b13c3e4a410cd10e37feb1718b2d1d9`.
Owner Pro was re-seeded on the Mini. Do not publish 1.3.3 until a rebuild
with that fix produces a Duplicate filesystem side effect.

Live log: `outputs/runtime/saneclick-1.3.3-action7-20260814.log`.

**Current public version:** `1.3.1` (build `1301`)
**Release candidate:** `1.3.3` (build `1303`)
**Release candidate state:** merged to `main` in PR #9
**Merged commit:** `9b95e95333d972078e62ff4c1ceaaf66e5027057`
**Audited fix commit:** `37c64a697b8cef6b8971afa6b6412ecf2be3bc5a`

## Active Release State

SaneClick direct downloads now use one customer path: a free 14-day trial with every feature, followed by a $14.99 one-time purchase. Retired Basic/Pro tier wording does not apply to the direct release. App Store product identifiers that contain `pro` are internal and belong to the separate App Store lane.

Public release note:

> Improves fresh-install Finder setup and custom action editing. Also polishes setup, purchase, and update screens.

### Current Mini receipts

- The signed 1.3.3 owner build reached `License / Status / Licensed` through the real Settings UI on the Mini.
- The Keychain access-group repair and its guardrail coverage are on the release branch. GitHub fixes #7 and #8 are merged.
- The shared Mini GUI runner cleanup is merged in SaneProcess PRs #22 and #24. Focused tests passed 31/31.
- Installed-runner acceptance returned status 0 with Finder frontmost, Terminal hidden, and zero accessibility-visible automation windows.
- The 1.3.3 custom-action manager now exposes visible, bright-white Edit and Remove controls. This fixes the Mini proof blocker where the row context menu did not appear through right-click, control-click, or its accessibility action.
- The focused visible-control guardrail and full canonical Mini verify passed: 190 tests in 22 suites. Workflow receipt: `3dab6efba777a4c98dbf4a7a460cb978`.
- The earlier 188-test Mini receipt remains at
  `outputs/verify/20260728T173755.694477Z-7777-691dfeca/01-test.log`; the
  190-test receipts above supersede it for this candidate.
- The earlier customer UI contract-only sweep passed source/manifest coverage:
  `03b0e58354c8e9e4c9060ae30732d8fe`. It is not an eight-action runtime receipt.
- Signed Release launch log: `outputs/runtime/saneclick-1.3.2-live.log`.
- Fresh direct-install Settings proof: `outputs/customer-ui/settings-fresh-direct-monitored-folders.png`.
- Signed-release Finder action produced a timestamped duplicate: `outputs/e2e/1.3.2/SaneClick-E2E-132_20260728_140633.txt`.
- Finder action log: `outputs/runtime/finder-e2e-1.3.2.log`.

The customer UI sweep receipt above established source and contract coverage. It did not execute every manifest click or Finder action. `scripts/customer_ui_action_sweep.rb` now writes contract-only receipts unless a separate Mini runner supplies action-level execution evidence.

Expected pre-publish warnings: public appcast and Homebrew remain on 1.3.1 until release, unrelated pending support email exists, and the audit ran in the evening.

## Fixed 1.3.3 Customer Proof — 2026-07-30

Candidate `37c64a697b8cef6b8971afa6b6412ecf2be3bc5a` passed the canonical Mini verify, and the conflict-resolved PR head `f8840077572046ad223aaca41d88e91bfe5ab481` passed 190 tests in 22 suites with receipt `c2d41a5c124350fd1c6e9876bfe427f7`. PR #9 merged to `main` as `9b95e95333d972078e62ff4c1ceaaf66e5027057`. The signed Release candidate launch receipt prefixes are `e7a027` and `5d9b4d`. No release or upload ran.

The fresh fixed-binary proof root is `outputs/customer-ui/1.3.3-20260730T054618Z-fixed/`.

1. **Passed — main category Enable All.** Transcript:
   `actions/01-main-category-enable-all.log`; screenshot:
   `screenshots/01-main-category-enable-all.png`.
2. **Passed — individual main-action toggle.** Transcript:
   `actions/02-main-individual-action-toggle.log`; screenshot:
   `screenshots/02-main-individual-action-toggle.png`.
3. **Passed — Script Library global controls.** The live read-back was
   `62/62 -> 1/62 -> 62/62`, with the global checkbox reading
   `1 -> 0 -> 1`. Transcript:
   `actions/03-script-library-global-enable-all.log`; screenshot:
   `screenshots/03-script-library-global-enable-all.png`. The earlier invalid
   diagnostic is retained as
   `actions/03-script-library-global-enable-all-invalid-readback.log` and
   `actions/03-readback-blocker.png`.
4. **Passed — Script Library category controls.** All five categories expanded;
   a category and its first row toggled off/on; final state returned to
   `62 of 62 enabled`. Transcript:
   `actions/04-script-library-category-controls.log`; screenshot:
   `screenshots/04-script-library-category-controls.png`.
5. **Passed — custom-action management.** Created `MD5 Hash`, saved body
   `echo CUSTOM_PROOF_FIXED_V2`, relaunched, edited it through the visible Edit
   button to `V3`, toggled it `1 -> 0 -> 1`, then used the visible Remove button
   and real confirmation dialog. The post-delete manager contained only
   `Start Python Server`, and the backing store was `[]`. Transcript:
   `actions/05-custom-action-management.log`; canonical screenshot:
   `screenshots/05-custom-action-management.png`; state receipts:
   `fixtures/05-custom-action-state-before-delete.json` and
   `fixtures/05-custom-action-state-after-delete.json`.
6. **Passed — Settings tabs and status.** General refreshed to
   `Extension Active`; General, Visibility, Updates, License, and About were
   selected and read through accessibility; Report a Bug opened only to its
   safe first surface and sent nothing; Privacy reached the end and displayed
   the local-data/public-GitHub warning. Canonical screenshot:
   `screenshots/06-settings-tabs-and-status.png`; transcript:
   `actions/06-settings-tabs-and-status.log`. The live License state was
   `Licensed`, so trial/$14.99 copy was not visible in this run.
7. **Blocked — real Finder menu action execution.** Direct-SSH `cliclick`, the
   researched Terminal/TCC context, and the System Events path did not expose a
   readable Finder context menu. The diagnostic desktop capture also stalled.
   The disposable fixture inventory remained unchanged and no Finder action
   produced a side effect. Retained evidence:
   `fixtures/07-before-inventory.txt`. There is no Action 7 pass screenshot.
8. **Not run / blocked by Action 7.** The fresh direct-install monitored-folder
   flow did not run because the required one-app proof sequence stopped at the
   Action 7 blocker. There is no Action 8 receipt.

This run is **not 8/8**. Do not run release/App Store preflights or claim
release readiness from it.

Cleanup completed after the blocker:

- The disposable Mini fixture directory
  `/Users/stephansmac/Downloads/SaneClick-Proof-20260730T054618Z` was moved to
  the Mini Trash and is recoverable there.
- Exact owned Mini processes were stopped: SaneClick PID `21641`, Finder
  extension PID `21642`, and live logger PID `17829`.
- The controller-side logger pipeline PGID `42693` (`ssh` PID `42704`, `tee`
  PID `42705`) exited.
- Final process read-back found zero SaneClick, logger, `mini-gui-run`,
  `cliclick`, or screenshot-helper processes. The proof Finder window was gone;
  Finder showed `Downloads`.

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

The July 29 Mini screenshot-wrapper blocker recorded on `main` was superseded
by the merged runner fixes. The remaining proof blocker is the Action 7 Finder
context-menu/capture path recorded above.

1. Fix or formally replace the blocked Finder action proof path, then rerun
   Actions 7 and 8 on the exact fixed 1.3.3 candidate.
2. Only after an honest eight-action runtime result, run the guarded release
   and App Store preflights.
3. Publish 1.3.3 only with owner approval, then verify the appcast, Homebrew
   cask, website, checkout, and hosted download.

## End-of-day preservation

- Air release checkout is clean at `a475245364eb216e8905f68a8d91218769431cef`.
- Mini primary checkout is clean on `main` at `2bbd52cf3367c108256616050bf2eca6ebd60f0c`.
- The old Mini Keychain worktree changes are recoverable in stash `18ea4473c396060014ea9d3127f368c637bac956`.
- The stale Mini release-worktree state is recoverable in stash `2bcf448e1715d7f51fc46de6ba2c686d93709db0`.
- Both stale linked worktrees were removed after checkpointing; the primary checkout is the only remaining SaneClick worktree on the Mini.

## Archive

- Direct 1.3.1 is the current public release.
- Direct 1.3.0 unified image handling on the native non-destructive path.
- App Store work remains a separate owner-gated lane.
