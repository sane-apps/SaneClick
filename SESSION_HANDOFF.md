# Session Handoff — SaneClick

**Last updated:** 2026-06-28
**Current public version:** `1.1.12` (build `1112`)
**Next release candidate:** `1.2.0` — combined feature release, code on `origin/main` (`ccc5005`), pending signed build + owner sign-off

## Current State

- 2026-06-29 (later) **1.3.0 SHIPPED to all direct channels (build `1300`, `a37b835`).** The unify landed: image actions run via the native engine on BOTH builds, non-destructive (write a new file via `uniqueDestinationURL`, never edit the original). Release notes were first written from a SAFETY angle ("your original photos stay safe") and the owner flagged it as worrying (implies the product was previously risky); reframed to a plain UPGRADE ("Upgraded photo handling: ... save the result as a new file rather than editing the original directly") and corrected across appcast + GitHub release + CHANGELOG, then `--website-only` redeployed (verified live). PENDING owner: the Lemon Squeezy hosted-file upload of the final 1.3.0 build (`hosted=1.2.0 expected=1.3.0`, product 800495), then `release.sh --version 1.3.0 --post-release-checks-only`. STILL OPEN: the image actions' real-app RUNTIME observation (they're Pro-gated; the Mini test app is Basic/expired-trial, and the launch/keychain guards correctly were not bypassed — owner to spot-check one action in a Pro session). **NEXT TRACK: revive the App Store (1.1.5 → current)** — build `Release-AppStore`, sandbox-verify the image actions, refresh screenshots/metadata/review-notes, confirm the App Store build HIDES the crypto/external-unlock paths the direct build advertises, `appstore_preflight`, then `appstore_submit.rb` (owner approves the listing copy + the submit-to-Apple).

- 2026-06-29 **1.2.0 + 1.2.1 SHIPPED (direct); image-conversion port committed; owner chose SHIP BOTH — direct 1.3.0 + revive the App Store (1.1.5 → current).**
  - **1.2.0 + 1.2.1 are LIVE on all direct channels** (build `1201`, `98d5267`): GitHub release, R2, appcast, Homebrew, email webhook, website. 1.2.1 fixed a live-only bug 1.2.0 introduced — the new OCR/PDF actions were buried at the bottom of a ~42-item FLAT Finder menu (truncated/unreachable); built-ins now carry `libraryCategory` so the menu groups into submenus by default (OCR reachable in Images & Media), LIVE-verified on the Mini Finder menu. **Only pending for 1.2.1: the manual Lemon Squeezy hosted-file upload** (`SaneClick-1.2.1.zip` staged in the Mini `~/Desktop/LemonSqueezy-Uploads/`; product `800495`); then `release.sh --post-release-checks-only`.
  - **Website optimized + redeployed** (`077a0bf`): OCR-led hero copy, action count 62, and the hero proof shot is now a clean grouped-Finder-menu screenshot (`docs/screenshots/ocr-finder-menu.png`) with Copy Text from Image in Images & Media.
  - **Image-conversion port — BUILT, ADVERSARIALLY REVIEWED, FIXED, 174 tests green, now COMMITTED to main locally (push + version bump handled by the 1.3.0 release).** Ports 10 image actions (Convert PNG/JPEG, HEIC→JPEG, Resize 50%, Resize 1920, Thumbnail 256, Remove Photo Info, Rotate 90° CW, @2x, Get Dimensions) to native Swift (`AppStoreNativeActionExecutor+Media.swift`) so they work on the SANDBOXED App Store build. `requiresNativeRuntime` stays FALSE → the **direct build is unchanged (still sips); the native code's payoff is the App Store build only.** Review caught + fixed: a CRITICAL blank-image rotate (test only checked dimensions), output-extension mismatch for HEIC/TIFF sources (PNG bytes in a `.heic` file), Convert-to-PNG sideways orientation, and partial-batch abort. Guardrail counts bumped pro 14→24 / allCases 27→37 (basic stays 13); all in lockstep. New tests now assert pixel CONTENT, not just shape.
  - **App Store channel status (corrected):** SaneClick **1.1.5 is LIVE on the Mac App Store** (id `6759330868`, free + Pro IAP, last updated 2026-04-16) — NOT dormant. But `.saneprocess appstore.enabled: false` disabled App Store *release automation* at 1.1.6, so the Store copy has been frozen at 1.1.5 while direct advanced to 1.2.1 (App Store users are 7 versions behind, and 1.1.5 predates native execution so its sandboxed sips actions wouldn't run). **DECIDED (owner 2026-06-29): SHIP BOTH** — direct 1.3.0 + revive the App Store (1.1.5 → current). The 1.2.1 Lemon Squeezy upload is SKIPPED (owner will upload the final 1.3.0 build to LS instead, to avoid a double upload). App Store path: build `Release-AppStore`, LIVE sandbox verify the image actions, refresh screenshots/metadata/review-notes, confirm the App Store build HIDES the crypto/external-unlock paths the direct build advertises (likely why it was frozen), `appstore_preflight`, then `appstore_submit.rb` (altool upload → ASC poll → submit for review; ASC creds in keychain). OPEN decisions: (a) direct-engine choice — keep direct on sips vs unify direct to the native non-destructive engine (resolves the cross-build divergence, gives direct users non-destructive image actions); (b) release-notes + App Store listing copy approval; (c) the submit-to-Apple go (outward-facing).
  - **Verification lesson codified** ("green tests, broken output"): for output-producing actions assert artifact CONTENT (a known pixel color at a coordinate, decoded text == expected, real format + matching extension), use adversarial fixtures (oriented/HEIC/bad-file batches), guard against blank output, and visually verify the real artifact on a real input before ship. Added to `DEVELOPMENT.md` ("This Has Burned You" + "Verifying output-producing actions") and memory `verify-output-content-not-shape`.

- 2026-06-28 **SaneClick 1.2.0 BUILT + on `origin/main` (`ccc5005`), verify-by-release pending.**
  Combined release line: keychain DP fix (`17bfa4a`) + #6 folder grouping (`321dbbf`) + 9 native
  actions (`ecb42f9`) + per-action output handling & ask-before-running + adversarial-review fixes
  (`ccc5005`).
  - New actions (both builds): OCR Copy/Save Text from Image (Vision), PDF Combine Images into PDF /
    Split PDF into Pages / PDF to Images (PDFKit), 4 copy-path variants (file URL / name w/o ext /
    parent path / Markdown link). All non-destructive (clipboard or new files via `uniqueDestinationURL`).
    A new `requiresNativeRuntime` flag routes ONLY these 9 through the native executor on the direct
    build too; the 18 existing actions keep their exact path (zero regression, locked by test).
  - New per-action settings (optional Codable fields, guardrail-neutral, default = current behavior):
    `outputMode` (When done: copy result / show window / notify) and `confirmBeforeRun` (NSAlert before
    file-changing actions, pre-enabled on the destructive built-ins). `DefaultScripts.swift` was split
    into `ScriptCatalog.swift` (over the 800-line limit; byte-for-byte preserved).
  - Verification: 147 tests green on the Mini, both the direct and `-D APP_STORE` compile paths. Built by
    an autonomous agent pipeline (research → 2-phase build → 16-agent adversarial review → fixes). Review
    caught + fixed an OCR EXIF-orientation bug (empty text on portrait photos) and a copy/notify-on-failure
    clipboard wipe — both now test-covered. App Store guardrail counts bumped in lockstep (basic 9->13,
    pro 9->14, allCases 18->27, freeCount 10->14, proCount 43->48, IAP copy "9 more"->"14 more").
  - Free/Pro split (flippable in `AppStoreActionCatalog` + the library `category`): copy-path = FREE,
    OCR + PDF = Pro.
  - Repo reconciliation: the prior "drift" was the Mini sitting 13 commits behind `origin/main` plus
    redundant uncommitted copies; fast-forwarded clean. All 17 stashes forensically confirmed redundant
    (only orphan = an abandoned ScriptExecutor file-watcher experiment in `stash@{4}` that also drops the
    Pro-license guard — NOT recovered). Air + Mini both clean on `ccc5005`. Nothing legit lost.
  - PENDING (owner / a signing-capable GUI machine): version bump 1.1.12 -> 1.2.0; customer release-notes
    approval (draft in this session's scratchpad); the signed release build (Mini signing
    `errSecInternalComponent`-blocked); the manual GUI checks (the 9 actions rendering in the right-click
    menu, OCR copy on a real PORTRAIT photo, destructive-action confirm Cancel aborting, result window
    Close/Escape, editor controls persisting, App Store sandbox writes); website `docs/index.html`
    "53 Built-in Actions" -> 62, separate gated deploy.

- 2026-06-27 keychain prompt-storm fix staged (ships next release, Monday):
  - Symptom (fleet-wide): after a direct-download update, macOS hammers users
    with "SaneClick wants to use your confidential information stored in
    com.saneclick.SaneClick" prompts. Root cause is the legacy login keychain's
    per-item ACL being bound to the creating build's code signature (TN3137);
    a new signature re-prompts on every item, every launch.
  - Fix: store the license in the modern data-protection keychain via SaneUI
    `f8e5274` (`kSecUseDataProtectionKeychain` + `kSecAttrAccessGroup` + one-time
    legacy→DP migration on first launch). Access group reuses the app's existing
    `M78L6FXD48.group.com.saneclick.app` application-group entitlement (macOS
    exposes app groups as keychain access groups), so **no new entitlement and no
    new provisioning profile** were needed.
  - Scope: only the non-sandboxed direct build (`#else` / `!APP_STORE` branch of
    `SaneClickApp.swift`). The sandboxed Mac App Store branch (`#if APP_STORE`) is
    unchanged — sandboxed apps already use the DP keychain and never had the storm.
  - Files: `SaneClick/SaneClickApp.swift` (accessGroup), `project.yml` (SaneUI pin
    83d8259→f8e5274), regenerated `project.pbxproj` + workspace `Package.resolved`,
    `CHANGELOG.md` ([Unreleased]).
  - Verified: Mini `./scripts/SaneMaster.rb verify` → 117 tests in 17 suites pass.
  - NOT yet verified (verify-by-release): the real SIGNED Developer ID build at
    release time (entitlement embeds + no runtime prompt + license migrates).
    Signing is headless-blocked over ssh; confirm on a GUI machine after the
    Monday signed build. The previously-created `com.saneclick.SaneClick Direct`
    provisioning profile is now UNUSED (app-group approach needs no profile).

- 2026-06-08 status refresh:
  - Live validation reports SaneClick `1.1.10` is consistent across appcast,
    website, webhook, Homebrew, and Lemon.
  - Release readiness is still blocked only by stale customer UI QA proof after
    source fingerprint changes; rerun the Mini customer UI sweep when the Mini
    is physically available.
  - Open GitHub item remains `sane-apps/SaneClick#6` for folder-based actions;
    it is an enhancement, not a current release blocker.
- 2026-05-25 09:33 EDT cross-product launch ops reran canonical Mini
  `launch_readiness`; it exited `1`, so the overdue launch-package lane stayed
  no-go and no scheduling, submission, or public posting action was executed.
  The blockers are unchanged: human visual approval plus a public URL are still
  missing for `docs/videos/saneclick-finder-workflow-30s.mp4`, the Product Hunt
  maker comment/day-of checklist still needs exact approval, Mini
  `release_preflight` still carries `3` warnings, and the shared validation
  report still flags stale SaneClick customer UI proof. Next checkpoint:
  `2026-05-26`. No new public URL was created in this run.
- 2026-05-24 23:23 EDT validation cleanup: Mini `customer_ui_sweep --json`
  refreshed 8 customer action families at `2026-05-25T03:22:26Z`; strict visual
  `customer_ui_contract` passed and `release_preflight` passed with warnings
  only.
- 2026-05-17 App Store listing repair attempt:
  - Generated valid macOS App Store screenshots at `docs/screenshots/appstore-*.png` and updated `.saneprocess` so the dormant/live-listing reference no longer points at general docs screenshots with invalid Apple sizes.
  - Verified the new screenshot set with `appstore_submit.rb --test-screenshots`; all four resize to Apple's `2880x1800` desktop target.
  - App Store Connect refused screenshot replacement on live `1.1.5` because the version is `READY_FOR_SALE`; current live screenshots are locked.
  - ASC currently has no `1.1.9` App Store version/build. Listing current direct `1.1.9` on the App Store requires a new App Store build/upload path, not metadata-only sync.

- 2026-05-15 launch-readiness cleanup:
  - Mini customer UI sweep passed and regenerated `outputs/customer_ui_action_receipt.json` with 8 covered actions.
  - Mini release preflight passed with warning-level cleanup only: uncommitted files, UserDefaults/migration upgrade-path warning, and pending customer emails.
  - The 30-second Finder workflow video was staged to `docs/videos/saneclick-finder-workflow-30s.mp4` with SHA-256 `c4c73b2f16a2ad75b6b02da93b273497ee870d255059ab3459426f8e88e0ce23`.
  - Remaining launch blockers are marketing/public-action gates: human visual approval and public deploy for the video, plus final Product Hunt maker comment and day-of checklist approval.

- 2026-05-12 SaneClick `1.1.9` fresh direct-install Finder menu proof is recorded:
  - GitHub release `v1.1.9` is published and `docs/appcast.xml` / `docs/index.html` point at `https://dist.saneclick.com/updates/SaneClick-1.1.9.zip`.
  - Fresh direct-install regression state was recreated on the Mini by moving aside existing monitored-folder storage, clearing `monitoredFoldersUserConfigured`, killing `cfprefsd`, then launching the signed Release app through `./scripts/SaneMaster.rb test_mode --release --no-logs`.
  - Fixed behavior was verified: SaneClick regenerated the standard monitored folders for Desktop, Documents, Downloads, Movies, and Pictures; Finder right-click on a PNG under Downloads showed SaneClick actions.
  - Clean visual evidence: `outputs/customer-ui/fresh-direct-proof-20260512T210332Z/fresh-direct-finder-menu-final-crop.png` and promoted copy `outputs/customer-ui/fresh-direct-downloads-menu-clean.png`.
  - `./scripts/SaneMaster.rb customer_ui_sweep --no-exit` and `./scripts/SaneMaster.rb customer_ui_contract --no-exit` pass with 8 release-required actions covered; receipt generated `2026-05-12T21:21:29Z` on host `mini`.
  - Mini `./scripts/SaneMaster.rb verify --timeout 1200` passed `116` tests after the fresh-install proof.

- 2026-05-11 SaneClick direct Finder menu hotfix shipped in `1.1.9`:
  - User-reported symptom: a direct-install MacBook Air had SaneClick 1.1.8 installed with actions enabled, but right-clicking an image in Finder/Recents showed no SaneClick actions.
  - Confirmed root cause: the direct app required `monitored_folders.json` for Finder Sync registration, but direct UI hid monitored-folder setup behind `#if APP_STORE`. Fresh or upgraded direct users could therefore have enabled actions and an enabled extension with no monitored Finder roots.
  - Missed-test cause: prior Mini QA manually seeded `/tmp/saneclick-finder-qa`, so it verified action execution only after monitoring was already configured and did not test the fresh direct install/no monitored-folder state.
  - Patch: direct builds now expose Manage Folders and Settings monitored-folder controls, seed standard user folders into App Group storage on startup unless the user has explicitly configured folders, preserve intentional empty user choices, and explain that Finder Recents is a smart view requiring the backing folder.
  - Additional cleanup: legacy built-in records whose content changed are recognized and canonicalized so old built-ins do not remain as duplicate custom-looking actions.
  - Verification: Mini `./scripts/SaneMaster.rb verify --timeout 1200` passed `116` Swift tests; release-mode clean-state launch created default monitored folders; GUI-session screenshot `outputs/customer-ui/fresh-direct-downloads-menu-clean.png` shows SaneClick actions in Finder for a PNG under Downloads; `./scripts/SaneMaster.rb customer_ui_contract --no-exit` passes with 8 required actions covered.
  - Release status: published as GitHub release `v1.1.9` on 2026-05-11; leave GitHub/customer follow-up open until reporter confirms unless the user approves closing/replying from this proof.

- 2026-05-11 SaneClick library activation fix shipped in `1.1.8`:
  - User-reported symptom: category Enable All buttons were intermittently ineffective and the UI could show impossible counts such as `30 of 10 enabled`.
  - Root cause: stale duplicate installed records for built-in library actions could accumulate, while some UI counts and toggles matched by action name instead of reconciling the canonical library action record.
  - Patch: `ScriptStore` now provides store-level single/bulk library activation APIs, canonicalizes built-in library scripts, deduplicates stale copies on load, and preserves a single live record per library action. `ContentView`, `ScriptLibraryView`, and `ActionCatalog` now use the canonical store path and deduped counts.
  - Verification on the Mini: `./scripts/SaneMaster.rb verify --timeout 1200` passed `108` tests; Release `test_mode` built/staged/launched `/Applications/SaneClick.app`; live AX click QA toggled Enable All off/on for all five categories, one individual action, the Script Library global control, all Settings tabs, and Refresh Status.
  - Screenshot evidence: SwiftUI render outputs generated at `/tmp/saneclick-visual-check/content-all-actions.png` and `/tmp/saneclick-visual-check/library-all-actions.png`. SSH live `screencapture` is currently blocked by Screen Recording permission on the Mini.

- 2026-05-11 SaneClick `1.1.7` is live across the direct-download release lane:
  - Release artifact: `https://dist.saneclick.com/updates/SaneClick-1.1.7.zip`; GitHub release `v1.1.7`; Homebrew cask `1.1.7`; appcast has exactly one `1.1.7` item; website download links are updated.
  - Release ZIP SHA256: `fdf1aa95c84ce7046a987678348a48cb1569c8211fc6cfb7fe1a4dcb8496b0b7`; size `2368514`; Sparkle signature `PDWTiKJlUKLan/hak+xZC2+f0LwWjHK+AXjuwHteX2WJ/AnDhJlfwh6HviIGYmCDqhEOY0Uoo7LwCtSpwN0RCg==`.
  - Mini release verification passed `106` tests, signed archive/export, notarization, R2 upload, appcast propagation, checkout redirect, GitHub release, website deploy, and Homebrew update.
  - Public GitHub reply posted to `sane-apps/SaneClick#4`; keep the issue open until reporter confirms. Work-email `#697` reply to Margot Olson was reviewed, reconciled, fact-verified, approved, and delivered; leave it pending customer confirmation/logs.
  - Release script published app/site/Homebrew successfully but initially failed at the email webhook push because the routed worker checkout used a stale local Mini remote. The canonical `sane-email-automation` worker was manually updated to `SaneClick-1.1.7.zip`, tested, pushed, and deployed. Signed SaneClick customer download URL now includes `/updates/SaneClick-1.1.7.zip` and downloads the expected artifact.

- 2026-05-11 SaneClick `#4` duplicate app-menu Settings item fixed in `1.1.7`:
  - GitHub `sane-apps/SaneClick#4` reported that app version `1.1.6` showed two `Settings` entries in the top-left app menu when the GUI was visible.
  - Root cause: the SwiftUI `Settings { ... }` scene already owns the app-menu Settings item, while `AppCommands` also replaced `.appSettings` with a custom Settings command.
  - Patch: removed the custom `.appSettings` command from `SaneClickApp.swift` and kept the SwiftUI Settings scene as the sole owner.
  - Test: `Tests/AppStoreReviewGuardrailTests.swift` now guards that `CommandGroup(replacing: .appSettings)` and the duplicate command-comma Settings shortcut are not reintroduced.
  - Verification on the Mini: `./scripts/SaneMaster.rb verify --timeout 1200` passed `106` tests; `./scripts/SaneMaster.rb test_mode --release --no-logs` built/staged/launched `/Applications/SaneClick.app`; menu inspection showed exactly one Settings item.
  - GitHub and email follow-ups are approved to post after `1.1.7` is live. Email `#697` from Margot Olson should not be claimed fixed without logs; reply should ask for an in-app bug report/logs from the updated build.

- 2026-05-09 shared menu/settings parity is the current operational baseline:
  - Dock right-click and menu-bar right-click are backed by the same SaneClick context-menu builder and expose the customer-critical path: Settings, License, Check for Updates, About / Report a Bug, and Quit, plus app-specific utilities where they are useful.
  - SaneClick settings uses the shared SaneUI settings chrome and a larger default window size so the content is not cramped.
  - The Finder extension readiness/settings block is intentionally compact and inline; avoid reintroducing a large explanatory wall of text.
  - Dock hidden by default and launch-at-login behavior should follow the shared SaneUI/SaneApps policy for utility-style menu-bar apps.
  - 2026-05-09 recovery note: the prior closeout overstated this work as shipped; the actual source/tag `v1.1.5` did not contain the shared context-menu implementation. The missing customer path was recovered into source on 2026-05-09.
  - Shared dependency requirement: SaneClick `Package.resolved` must point at SaneUI `ce1df3c2b03d8ade3b300e907fbcf37320a847bc` or newer for `SaneStandardMenu` and embedded settings sizing.
  - Latest recorded Mini verification for the recovered parity pass: `./scripts/SaneMaster.rb verify --timeout 1200` passed 98 tests, and `./scripts/SaneMaster.rb test_mode --release --no-logs` launched the signed Release app from `/Applications/SaneClick.app`.
  - 2026-05-09 TCC scope fix: repeated “SaneClick wants to access data from other apps” prompts were traced to Library/App Group access during normal launch, plus the risk of persisted monitored folders inside `~/Library`. `MonitoredFolders` now rejects and purges every monitored folder under `~/Library`, and the host app no longer reads App Group execution files on ordinary launch. The Finder extension only launches the host with `--saneclick-execution-requested` when an execution request exists.
  - 2026-05-09 settings copy fix: the General tab’s Finder extension control is labeled `Finder Extension` / `Manage Finder Extension`, not the ambiguous `Actions` / `Open Settings`; `Localizable.xcstrings` was updated so the built app does not revert to stale copy.
  - 2026-05-09 release-lane correction: `.saneprocess appstore.enabled` is now `false`, matching the current direct-download-only strategy. App Store metadata is dormant reference only; normal release readiness should use `release_preflight`, not `appstore_preflight`.
  - Latest recorded Mini verification after TCC/copy fixes: `./scripts/SaneMaster.rb verify --timeout 1200` passed 105 tests. Release-mode proof: reset `SystemPolicyAppData`, launched signed Release `/Applications/SaneClick.app`, opened settings, captured `/tmp/saneclick-settings-label-fixed-2.png`, and no `com.saneclick.SaneClick` TCC row was recreated.
  - Release remains blocked until unresolved `auto-reconcile-*` stashes are triaged. SaneProcess release preflight now detects stashed source/docs/tests that differ from `HEAD`.
  - Live GitHub state from the prior closeout reported no open SaneClick issues; recheck before any public release or customer reply.

- Pricing rollout approved on 2026-04-14: direct and App Store copy should present `Basic free + Pro $9.99 once`. Keep StoreKit product ID `com.saneclick.app.pro.actions.v4`.
- Pricing language should stay consistent across README, `docs/index.html`, long-tail guide CTAs, and App Store-facing copy. No apology pricing copy.
- Track rollout impact with three simple checks: direct checkout conversion from website CTA traffic, App Store unlock rate, and activation-to-paid conversion after the copy update goes live.
- Use `CHANGELOG.md` for current release history and `project.yml` for the authoritative version/build.
- The old MCP migration and January org-audit notes below are archival; they are not the current product or release summary.
- Keep this file focused on current operational state going forward.

## Archived Notes

## ✅ COMPLETED: Xcode 26.3 MCP Migration (Feb 13, 2026)

Apple released **Xcode 26.3 RC** with `xcrun mcpbridge` — official MCP replacing community XcodeBuildMCP.

**Migration completed:**
- ✅ Global config: `~/.claude.json` has `xcode` server, `~/.claude/settings.json` has `mcp__xcode__*` permission
- ✅ **`CLAUDE.md`** — Already references `xcode` MCP (lines 48, 57-67, 82), no XcodeBuildMCP references
- ✅ **`.mcp.json`** — Already has `xcode` server via `xcrun mcpbridge`, no XcodeBuildMCP entry
- ✅ Project-specific scripts (dependencies.rb, meta.rb, bootstrap.rb) are in SaneProcess (global), not this project

**xcode quick ref:** 20 tools via `xcrun mcpbridge`. Needs Xcode running + project open. All tools need `tabIdentifier` (get from `XcodeListWindows`). Key tools: `BuildProject`, `RunAllTests`, `RunSomeTests`, `RenderPreview`, `DocumentationSearch`, `GetBuildLog`.

---

## Latest Session: Org Audit & Website Fixes (Jan 30, evening)

### Website Changes (all committed & pushed)
- **Known limitation disclosure** on saneclick.com with 3 embedded Apple bug proof links
- **Crypto payment section** added to SaneClick with BTC, ETH, SOL, ZEC + "How it works" flow (email tx proof → get DMG)
- **ETH address added** across ALL sites (was on saneapps.com only, missing from SaneBar, SaneClip, SaneClick, SaneHosts)
- **SaneHosts crypto section** — had CSS but no HTML, now complete

### Org-Wide Fixes (all committed & pushed)
- **Signing identity** — removed hardcoded `"Stephan Joseph"` from SaneBar, SaneClip, SaneSync, SaneVideo project.yml. All now use generic `"Developer ID Application"`
- **Sister apps lists** — replaced "SaneScript" with "SaneClick" in SaneBar, SaneHosts, SaneVideo, SaneSync, SaneAI CLAUDE.md files
- **Deleted duplicates** — `~/CLAUDE.md` (duplicate of `~/.claude/CLAUDE.md`), `~/SaneApps/infra/sane-skills/` (orphaned), `SaneClip/homebrew/`

### Model Strategy (updated in skills)
- All subagent skills (`/critic`, `/sane-audit`, `/docs-audit`) now use **Sonnet** instead of Haiku
- Strategy: Opus for main session (planning/decisions), Sonnet for all subagents, Gemini Flash for memory
- "Haiku reads, Sonnet works, Opus decides"

### Maintenance
- **SaneVideo lefthook** — installed 132 Ruby gems via `bundle install` (was failing on push)
- **SaneAI remote** — switched from SSH to HTTPS to match other repos
- **SaneClick uncommitted changes** — committed entitlements fix (host sandbox OFF, extension sandbox ON) and rebranded app/extension code
- **Screenshots folder** cleared

### Crypto Payment Flow (NO automation exists)
- Websites explain: send crypto → email hi@saneapps.com with tx proof → manual verification → send download link
- No automated crypto verification in sane-email-automation — would need a new handler if desired

## Verification
- All repos clean (no uncommitted changes)
- No orphaned processes
- 6.1 GB RAM available
- All pushes successful

## Next Steps
1. **Video Demos** — film real usage videos for all products
2. **SaneClick Guides** — expand library (currently 1 guide)
3. **Crypto automation** — optional: build email handler for transaction verification
4. **SaneVideo lefthook** — Ruby gems installed but verify `lefthook install -f` runs clean

## Critical Rules
- **Signing:** Generic `"Developer ID Application"` everywhere (Xcode resolves via Team ID)
- **Model strategy:** Sonnet for subagents, Opus for main, Gemini Flash for memory
- **Skills are global:** `~/.claude/skills/` is single source of truth, never duplicate into projects
- **One Sparkle key:** `7Pl/8cwfb2vm4Dm65AByslkMCScLJ9tbGlwGGx81qYU=` for ALL SaneApps

## Launch Ops Calendar - 2026-05-14

- `.outreach.yml` now classifies SaneClick as `released_but_no_meaningful_public_launch_yet`.
- Scheduled gates: launch readiness package on 2026-05-22 and PH/HN decision on 2026-05-26. Required before launch: Finder workflow demo, pricing/checkout consistency, PH package, and fresh Mini customer UI proof less than 7 days old.
- 2026-05-14 launch package update: generated local Product Hunt candidate assets at `docs/images/product-hunt-thumbnail-240.png` and `docs/images/product-hunt-gallery-01.png` through `03.png`, plus `Videos/saneclick-finder-workflow-30s.mp4` (1920x1080, 30.0s). Current launch gate remains no-go until human visual approval/hosting, final maker comment/day-of reply checklist approval, and fresh Mini verify/customer UI proof.

## Launch Ops Calendar - 2026-05-15

- Mini `./scripts/SaneMaster.rb launch_readiness` returned nonzero for SaneClick. No Product Hunt, Hacker News, directory, or public reply action was taken.
- Launch blockers remain unchanged: the Finder workflow video is still local-only and needs human visual approval plus hosting, the Product Hunt maker comment/day-of reply checklist still needs exact approval, and the launch gate still reports the fresh Mini verify/customer UI receipt requirement as incomplete.
- Existing listing URLs remain support surfaces only: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/697).
- Next launch-ops date stays 2026-05-22 for the package pass.

## Launch Ops Calendar - 2026-05-16

- Mini `./scripts/SaneMaster.rb launch_readiness --json` stayed red for SaneClick, so no Product Hunt, Hacker News, directory, or public reply action was taken.
- Fresh blocker receipt: the Finder workflow video still needs human visual approval plus hosting, the Product Hunt maker comment/day-of reply checklist still needs exact approval, and the launch package is still incomplete even though `release_preflight` remains green with 3 warnings.
- Existing listing URLs remain support surfaces only: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/697).
- Next launch-ops date stays 2026-05-22 for the package pass.

## Launch Ops Calendar - 2026-05-17

- Mini `./scripts/SaneMaster.rb launch_readiness --json` stayed red again for SaneClick, so no Product Hunt, Hacker News, directory, or public reply action was taken.
- Fresh blocker receipt: the Finder workflow video still lacks human visual approval and a hosted public URL, the staged `docs/videos` asset is not deployed publicly yet, the Product Hunt maker comment/day-of reply checklist still needs exact approval, and `release_preflight` remains warning-only with 3 warnings.
- Existing listing URLs remain support surfaces only: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/697).
- Next launch-ops date stays 2026-05-22 for the launch-package pass.

## Launch Ops Calendar - 2026-05-18

- Mini `./scripts/SaneMaster.rb launch_readiness` stayed red again for SaneClick, so no Product Hunt, Hacker News, directory, or public reply action was taken.
- Fresh blocker receipt: the Finder workflow video still lacks human visual approval and a hosted public URL, the staged `docs/videos` asset is not deployed publicly yet, the Product Hunt maker comment/day-of reply checklist still needs exact approval, and `release_preflight` remains warning-only with 3 warnings.
- Existing listing URLs remain support surfaces only: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/697).
- Next launch-ops date stays 2026-05-22 for the launch-package pass.

## Launch Ops - 2026-06-23

- Cross-product launch ops reran canonical Mini `./scripts/SaneMaster.rb launch_readiness --json` from the SaneClick repo. It stayed red.
- Active blockers are unchanged: the 30-second Finder workflow video still needs human visual approval plus a hosted/public URL, the staged `docs/videos` asset still is not deployed publicly, and the Product Hunt maker comment/day-of reply checklist still needs exact approval.
- Fresh proof state: `release_preflight` still passes but is stale at 29.42 days with 3 warnings, and the shared validation receipt [`/Users/sj/SaneApps/infra/SaneProcess/outputs/validation/2026-06-23.json`](/Users/sj/SaneApps/infra/SaneProcess/outputs/validation/2026-06-23.json) is still `NOT READY FOR RELEASE` with stale SaneClick customer-UI proof plus missing transcript/fixture artifacts. No scheduling, submission, posting, or public reply action ran today.
