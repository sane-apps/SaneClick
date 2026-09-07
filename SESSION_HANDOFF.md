# Session Handoff — SaneClick

## 2026-09-07 02:38 ET — Library identity regression verified and owner state restored

- Library counts and both category/All Scripts rows now reuse existing ActionCatalog classification, preserving same-name custom records and legacy/duplicate handling. Six focused tests pass, including enabled-custom/disabled-built-in in both input orders.
- Actual signed app global switch changed62 built-in flags only; custom Start Python Server remained enabled. All counts correctly zero. Native search using AXSetValue exposed the affected row; actual row on/off produced1/62 then0/62. All Scripts expansion also displayed the affected built-in disabled. No script was executed.
- Three clean inspected screenshots02:28:02,02:35:09,02:36:40 and assertions are in outputs/customer-ui/portfolio-20260907/library-identity-regression.json. These cover this defect in the paid owner state, not all8actions/entitlements. The unscrolled diagnostic images are private tooling evidence, not full-view clearance.
- Owner config RESTORED: real global switch back on, scripts.json and monitored_folders.json semantically identical to original backups; library-fixed-owner-restoration.json. Done dismissed sheet; normal Quit stopped app81405 and live capture06:37:40Z/app_exited. Runtime receipt outputs/runtime-logs/20260907T062639Z-20260907-81178-ghpt40/receipt.json.
- Tool lesson verified: sheet AX set-value works with --snapshot and --on ONLY; do not combine window/app/PID flags. Parent-target background type refuses sheet focus; parent foreground focus times out; background scroll unsupported. Read error before acting. Shared scripts/mini/SCREENSHOT_TOOLS.md now documents this; Mini/Air file parity maintained. Foreground scroll remains unverified.
- Default GitHub auth passes on Air/Mini with normal environment AND token overrides unset; both MrSaneApps. Receipt github-default-auth.json contains identities only.
- Direct-main native fix commit/push next; preserve pending scripts/customer_ui_action_executor.rb containment guard and shared infra dirties. Full customer executor replacement, other workflow cases, version bump/release/LS remain pending. Overall goal ACTIVE.


## 2026-09-07 02:31 ET — Library identity fix passes; runtime proof active

- New real bug: disabled built-ins still reported 1/62 enabled because a custom Start Python Server action shares a built-in name. All 62 built-in enabled flags changed correctly; custom record/content remained intact. Library row lookups and enabledCount used name alone.
- Reused existing ActionCatalog.libraryScripts for both row lookups and counts. Added same-name enabled-custom/disabled-built-in regression in both input orders; focused ActionCatalogTests 6/6 pass, workflow f0a26272e57d17a5c9c6cadb7bde9962. Native files match both hosts; not committed yet.
- Signed runtime workflow e12132280061ccc81238d243cd5bc823 ACTIVE: PID81405, process identity1788762399217727, window2821. Live log outputs/runtime-logs/20260907T062639Z-20260907-81178-ghpt40/receipt.json expires07:26Z. Old runtime77181/log stopped06:24:55Z/app_exited.
- Actual global off now reports 0/62 and all five categories zero. library-identity-regression.json asserts old failed count versus new count; library-fixed-off-file-proof.json verifies62 enabled flags only and custom preserved. Clean screenshot02:28:02 inspected readable, balanced, correct zero counts. Expanded Coding AX reports all12 disabled, including same-name Start Python Server; visible-row screenshot still pending.
- STATE TO RESTORE: owner built-ins currently all disabled for this test; custom enabled unchanged. Restore via library global switch before quitting, then compare owner-state-before.json backups semantically. Do not overwrite owner data. Owner baseline63 records,62 built-ins+1 custom.
- Peekaboo background scroll cannot AX-scroll this sheet. Documented foreground retry failed exact-parent-window focus because sheet is key. Both failures retained; fresh AX and screenshot02:30:01 show sheet healthy and unscrolled. Second diagnostic screenshot pending. Stop blind retries; use supported sheet interaction after observation/research. These are tool focus failures, not evidence app hung.
- Main paid-state proof completed all five off/on category pairs and individual Copy Path off/relaunch/persist/on; owner config restored after those flows. Receipts under outputs/customer-ui/portfolio-20260907. Paid-state partial only; full8-actions/entitlements/fresh-install and honest executor replacement remain open.
- Default gh credentials freshly rechecked on both hosts with GH_TOKEN/GITHUB_TOKEN and enterprise overrides unset: both authenticated MrSaneApps. No token disclosed or replaced.


## 2026-09-07 02:06 ET — Customer workflow proof active; unsafe QA claims blocked

- Source review found scripts/customer_ui_action_executor.rb marks manifest steps complete without performing them: main category plan only navigates, global library plan only opens/closes, custom plan only opens manager; Finder uses internal pending_execution.json, fresh install merely inspects current storage. It also raw-spawns force-Pro and compiles a fresh AX helper from a stale sibling path. These are not complete8-action receipts. SaneHosts contains the same manifest-copy pattern; assess its actual plans separately before trusting them.
- Interim fail-closed guard now stops --execute before GUI setup/receipt writes; --plan remains available. Shared customer_ui_evidence_integrity_test.rb regression failed8/9 before and passed9/9 after. Both changed files match Air/Mini, uncommitted. This is containment, not a rebuilt executor: replace its legacy execution with actual observed workflows, retain full scope, remove copied claim fields and old helper/raw-launch paths. AgentMemory a41d676b-e8ba-4c27-b042-a00be762022b records issue.
- Actual paid-owner UI pass uses canonical signed launch with live log from before launch; workflow10e9f5603adeacd426ed60c7824e677c. ACTIVE appPID72043/window2755; runtime receipt outputs/runtime-logs/20260907T055739Z-20260907-71981-9d39jo/receipt.json, deadline06:57:39Z. Before ending, normal-quit and verify log supervision stops.
- Existing scripts.json and monitored_folders.json copied without alteration to outputs/customer-ui/portfolio-20260907/owner-state-before/. Live JSON remained semantically identical after three category off/on pairs. Do not replace owner data blindly; restore test changes through UI and compare this baseline.
- Real main category toggles passed Essentials14->0->14, Files & Folders9->0->9, Images & Media15->0->15 with every row switch read back. Exact-window Peekaboo snapshots required: --window-id2755 --tree --no-screenshot; app-only snapshot was rejected as incomplete before any observed state change. Click/read-back receipts in portfolio-20260907; raw app snapshot failure retained.
- Clean private screenshots inspected02:00:46 (Essentials all-on),02:02:18 (Essentials all-off),02:04:48 (Files & Folders all-on). Images & Media screenshot capture currently running; inspect it before moving the UI. This is paid-state partial proof, not completed manifest or release clearance. Next Coding/Advanced toggles, individual-toggle persistence, real library controls, custom CRUD/same-name preservation, fresh monitored-folder setup, remaining settings/entitlement cases. Earlier actual five Finder category/file proofs remain separate source-bound evidence.


## 2026-09-07 01:52 ET — Guide release live; workspace fix on main

- SaneClick direct-main push completed at4e1609bb6bb87e2402e9271a8e73a9a4316d4f55 (guide commit3ad3edb plus workspace fix4e1609b), independently confirmed by git ls-remote. No PR created. Required pre-push full197-tests/22-suites PASS; workflow44ca3260af12d2197c018b22fd591abd, outputs/portfolio-guide-facts-final-20260907/push-final.log.
- Air's seven pending files were byte-identical to origin/main. Preserved them in stash portfolio-click-guide-minimum-before-main-sync-20260907, then fast-forwarded. Both hosts reached the same clean code commit before this receipt note. Do not reapply the superseded stash.
- Canonical release.sh --website-only completed; deployment https://7b7f0762.saneclick-site.pages.dev serves saneclick.com. Public14-page/viewport layout checks PASS. Allfour changed HTML pages match inspected source exactly after removing the one exact extra Cloudflare-injected analytics script; content unchanged. layout-live.json and live-guide-parity.json retain the actual assertions/hashes and exact removed line. Initial raw-byte assertion failed only because of this injection; one bare Python urllib request got403, while named SaneApps-QA requests and real browser checks succeeded. No source or behavior override used.
- Eight guide screenshots retain inspected:true receipts. Two clean native workspace screenshots plus AX resize bounds, unchanged1/1 focused test and stopped signed runtime are in window-minimum-visual-verification.json. These private receipts are copied to both hosts. Active native app/log/helper processes from this run stopped; installed Finder extension remains OS-managed. Preview server60504 absent.
- Shared AgentMemory tracks minimum-size cause/fix and guide release. Overall portfolio goal remains ACTIVE: full native customer workflow and versioned artifact release/LS replacement still pending. Installed modified1.3.3 is not a new public app release.
- Process follow-up found during this lane: verify diagnostics searches legacy locations, misses its own outputs/verify/*.xcresult and points to stale test_output.txt. Fix its exact-result handoff with a regression; do not use stale logs. Also inspect manual+Cloudflare automatic analytics beacon coexistence before assuming event counts are deduplicated. No claim of duplicate events yet.


## 2026-09-07 01:47 ET — Workspace minimum verified in signed runtime

- One-line native SwiftUI minimum passed the unchanged restored-license-window regression1/1. Signed workflowd5c07c3b6092d705ed7e3b790ca999e8 built and launched current source with a live log attached before launch.
- Clean private screenshots01:43:54 (1040x772) and01:45:15 (800x552) in outputs/portfolio-guide-facts-final-20260907 were inspected: readable action descriptions, switches and sidebar; long lists scroll at the viewport boundary. A400x300 resize request was clamped to800x552; Peekaboo reported it did not reach the deliberately invalid requested size, and fresh AX read-back proved the expected minimum. Restored1040x772 before normal Quit.
- Runtime log receipt outputs/runtime-logs/20260907T054232Z-20260907-67091-tu9gww/receipt.json stopped05:46:07Z/app_exited. App67269/log67266/supervisor67265 are absent. Python prompt-resolution screenshots01:36/01:38 are private permission evidence only.
- Source commit/full pre-push suite/public guide deployment are next. No native version bump, ZIP release, LS change or full customer-workflow clearance claimed.


## 2026-09-07 01:42 ET — Push gate found a real workspace minimum-size bug

- Guide-copy commit3ad3edb remains local on Mini; origin/main and Air HEAD remain662e655. Pre-push failed only VisualVerificationRenderTests/workspaceReleasesLicenseSizedWindow: content expanded1040px but NSWindow.minSize.width was474 instead of800. Current failing log and xcresult: outputs/verify/20260907T053001.274269Z-63206-f60922cc/. The wrapper's advice to use test_output.txt was wrong; that file was from July.
- NSHostingController defaults to standardBounds and updates window contentMinSize from SwiftUI (Apple docs https://developer.apple.com/documentation/swiftui/nshostingcontroller/sizingoptions, verified with installed SDK). ContentView lacked a SwiftUI minimum. One native .frame(minWidth:800,minHeight:500) now expresses the same workspace minimum as the shared window helper; source matches both machines. Existing regression unchanged and passed1/1, workflow4f4faad84f7b75262918b0daac32603f, outputs/monitor-tests/20260907T054044.561720Z-65784-53854eb1/receipt.json. Signed runtime/visual and full pre-push verification pending.
- First focused command selected zero tests because Swift Testing's exact selector needs trailing parentheses; monitor_tests correctly rejected it. The app's scripts/SaneMaster.rb is a shell wrapper, so invoke directly, not via ruby. Preserve both failure logs in portfolio-guide-facts-final-20260907.
- Private clean Mini screenshot01:36 showed a Python local-network prompt. Native Allow clicked under owner standing authorization; screenshot01:38 confirms prompt gone. This is consent read-back, not a fresh Python network-feature test. Signed-in Mini Brave preserved. Preview PID60504 is absent. Air guard renewed until17:41Z without changing lock/logout preferences.
- Broader goal remains active. Do not call native release or guides deployed until remaining proof succeeds.


## 2026-09-07 01:17 ET — Guide factual corrections ready to publish

- Rewrote three existing guide articles (batch rename, image conversion and photo metadata) to describe real outcomes without unsupported negative comparisons. Updated guide cards, titles/descriptions/JSON-LD/dateModified and readable source-link styling. Kept existing layout.
- Traced native execution through ScriptExecutor, AppStoreNativeAction and Media executor. Remove Photo Info writes a unique _clean sibling, leaves the original metadata intact, uses ImageIO rather than sips, and does not guarantee unchanged quality or zero technical metadata. Conversion creates a still image from the first frame and writes a new sibling. Current native media implementation dates to June29, before public1.3.3; existing197-test suite includes real GPS/UserComment/make/model removal and conversion fixtures.
- Current Apple primary guides confirm Finder text replacement/numbered formats and Preview batch conversion. Links and lasting claim constraints are in ARCHITECTURE.md, which also replaces stale no-telemetry and DMG release wording. Public copy describes limitations without implying a new native feature.
- Eight clean screenshots inspected: outputs/portfolio-guide-facts-final-20260907 (three articles desktop/375) and outputs/portfolio-guide-facts-20260907/guides-{desktop,375}. Each receipt records the visual verdict. Earlier article captures with default dark-blue source links are superseded.
- Preview layout checks passed14 page/viewport cases. Shared SEO tests10/10 and95-page audit pass. Source edits match both machines; direct-main commit/push and canonical website deploy/live proof next. No native code, version, LS or permissions changes.
- Separate remaining risks: exact native full-workflow release coverage remains open; direct rename scripts report completion even when mv -n skips name collisions, and sequence rename needs extensionless/conflict testing. Do not infer every batch item changed from its notification. Continue full portfolio audit.

## 2026-09-07 01:00 ET — SaneClick website published and public proof passed

- Commit 662e6552eb2533a40bfe3c34d55e540869281bf7 pushed directly to main with no new PR. Required pre-push native verification passed 197 tests in 22 suites; log apps/SaneClick/outputs/portfolio-web-layout-20260907/push.log. Air fast-forwarded after preserving its identical pending diff in stash portfolio-click-website-before-main-sync-20260907; both hosts reached the same clean source commit before this receipt update.
- Canonical release.sh --website-only succeeded without Keychain prompts. Cloudflare Pages deployment https://20d02d90.saneclick-site.pages.dev serves saneclick.com. Appcast/manual download route verified at existing public 1.3.3; no native binary or LS upload was changed.
- Public layout-live.json passed all 14 page/viewport assertions: H1 clear of nav, no horizontal page overflow, Donate destination and pink fill correct. Six guide HTML responses are byte-identical to source. Homepage becomes exactly identical after decoding Cloudflare's two email hrefs/one email span and removing its exact email-decode script; no other transform. See live-source-parity.json and deploy.log.
- Actual desktop and 375px Donate clicks from the preview reached https://github.com/sponsors/MrSaneApps with the correct Sponsor title and account visible (donate-clicks.json). Final 14 inspected screenshots remain in the directories recorded below; these are private QA.
- Shared SEO tooling files now match Air/Mini; tests 10/10 and local audit 95 pages pass. Their changes remain uncommitted in the existing SaneProcess portfolio branch alongside prior work; preserve and review that full branch before a direct-main integration.
- Preview server PID55156 stopped deliberately after verification; earlier PID51190 also stopped. Both owned SSH sessions ended. No native QA app remains from this website lane. Signed-in Mini Brave session untouched.
- Next: continue remaining SaneClick native eight-action workflow/fresh-install coverage and bump/release only after gates pass; audit guide factual copy against current native/shell behavior (Finder rename, Preview export, image/EXIF claims). Continue other portfolio runtime/iPad/release/LS/machine-sync lanes. Overall goal remains active, not complete.

## 2026-09-07 00:55 ET — Website defects fixed and verified; deploy pending

- Corrected six live Donate anchors from product checkout to GitHub Sponsors, kept heart interiors pink, removed six zero-telemetry slogans contradicting disclosed aggregate counts, and removed the redundant blanket on-device comparison row/metadata wording.
- Five guide titles were hidden behind fixed navigation. A real Mini browser regression failed headingTop 0 < navBottom 88.84. Existing article.container selectors now preserve vertical padding; mobile top spacing accommodates wrapped navigation. Fourteen desktop/mobile layout checks pass, including no horizontal page overflow and correct Donate URL/pink fill.
- Fourteen clean final page/viewport images inspected: outputs/portfolio-web-layout-20260907 (five guides and homepage at desktop/375, reduced motion) plus outputs/portfolio-web-final-20260907/guides-{desktop,375}. Each receipt records the actual visual verdict. Old guide captures with clipped titles are superseded. Homepage scroll animations hide offscreen content in full-page no-preference captures; reduced-motion captures show it. Mobile comparison tables scroll inside containers.
- Runnable check and before/after JSON: outputs/portfolio-web-final-20260907/check-layout.cjs and layout-{before,after}.json. Shared SEO audit passed 10 tests and 95 pages across its eight configured sites. It now catches Donate links aimed at SaneApps /buy routes and accepts the configured SaneScan social-card.png while rejecting paths outside the site. The two shared audit files match Air/Mini.
- This is scoped link/layout/privacy-copy verification, not a full factual clearance of historical guide and competitor claims. Guide wording about Finder rename, Preview batch export and sips metadata removal needs a source/current-runtime content audit. Native release and broader portfolio work remain pending.
- Website commit/push/deploy and live read-back remain next. No native artifact or LS upload changed.

## 2026-09-07 00:27 ET — Native fixes pushed; Air and Mini source aligned

- Direct-main push succeeded: SaneClick2ecc816bc22ff827e31e0b0a8f6e7fa66e27ba04. Remote refs/heads/main independently read back at that SHA. No PR created. Git pre-push ran the canonical full suite again:197 tests/22 suites PASS, workflow c612944566bcd38c5c9e5e739e4476e7, outputs/verify/20260907T042332.348342Z-48907-c4de2050/01-test.log.
- Pre-commit lint removed one extra blank line in VisualVerificationRenderTests; pre-push tested the committed result. The 12 committed files include shared SaneUI pins, native fixes/tests and documentation. Seven website files remain uncommitted.
- Air fast-forwarded from580316e throughd0bd558 to2ecc816. Preserved previous Air work in recoverable stash6a718ed40f70dd51bf02909ea5652e379692c4a9 (portfolio-click-before-main-sync-20260907). Reapplied its website-only patch and brought the new header heart to the same pink as Mini. All19 touched files had identical SHA256 on both hosts after sync.
- Five Finder category actions and stopped runtime are recorded in finder-action-verification.json. Existing broad workflow/release tasks and guide Donate-link repair remain open. Source push is not an app or website release.


## 2026-09-07 00:23 ET — Five real Finder categories verified; source ready for main

- Actual Finder context-menu clicks passed one representative action in every category: Duplicate with Timestamp, Replace Spaces with Underscores, Convert to JPEG, Format JSON and Create SHA256 File. Byte/hash, rename, JSON-content and image-format/dimension assertions all passed. No IPC request was injected.
- Ten clean inspected menu/result screenshots and hashes are recorded in infra/SaneProcess/outputs/portfolio-review-20260906/click-settings-visual/finder-action-verification.json on both machines. Private QA only. Disposable inputs/results moved from Downloads/saneclick-portfolio-agyztmt6 to finder-artifacts in that output directory; the fixture Finder window is closed.
- Normal Quit stopped the signed runtime at2026-09-07T04:21:06.420063Z/app_exited; app36850/log36846/supervisor36845 are absent. Live capture ran before launch through the actual actions. The capture records system/app activity; action proof is the observed menu selection plus independently verified file results.
- Full197-tests/22-suites pass and native source/config/test/doc hashes match Air/Mini. Reviewed native change is ready for a direct-main commit/push under owner authorization. No version bump or app release is claimed; complete the remaining eight-action workflow and release gates before publication.
- SaneProcess native screenshot runner fix passed38 checks and actual open-menu capture. Production fix reuses restoreBundleID and skips focus changes when already frontmost. Updated SCREENSHOT_TOOLS.md supersedes old advice calling native GUI capture unreliable. These shared tooling changes remain uncommitted among prior portfolio changes.
- Newly found website bug: docs/guides.html Donate links to app checkout. Audit sibling guide Donate anchors, correct to the established Sponsor destination and verify before website release. Existing pink-heart website changes remain outside the native source commit. AgentMemory bf6461db-80cc-424d-8aa8-97577266fe45 tracks this open issue.
- Remaining portfolio work continues; this is neither full customer-workflow clearance nor overall completion.


## 2026-09-07 00:06 ET — Full suite and first real Finder action passed

- Full canonical SaneClick verification passed 197 tests in 22 suites, workflow 0e0948e97ebcc0e5a790ca70828270ea. First run failed only three expected-pin assertions in AppStoreReviewGuardrailTests; updated expected SaneUI revision to reviewed 60176f3 on both machines. Entitlement assertions unchanged. Logs: infra/SaneProcess/outputs/portfolio-review-20260906/click-settings-visual/release-suite{-final,}.log.
- Signed runtime workflow 0cac366762f9e86e823d7ec113498e0e is ACTIVE; live log/receipt apps/SaneClick/outputs/runtime-logs/20260907T035034Z-20260906-36540-gv6zqt. Deadline04:50:34Z. Must normal-quit and verify owned log processes stop when finished.
- Actual Finder menu Essentials > Duplicate with Timestamp clicked at04:04:53Z on disposable Downloads/saneclick-portfolio-agyztmt6/Example File.txt. Created Example File_20260907_000454.txt; bytes and SHA256638aa9bb72ac58f87324a7bf8c64524e86d51f6493118f9e7a8e010e01330f78 match original. Clean inspected private screenshots00-04-01(menu) and00-05-27(result).
- Found screenshot GUI launcher stalling120s after successful capture because redundant Finder activate waits while Finder tracks an open menu. Existing restoreBundleID helper now returns immediately for already-frontmost process; default Finder focus reuses that helper. Mini38/38 GUI runner checks pass and canonical screenshot00-02-47 returned0 preserving menu. Two-line production fix + existing test expectation updated on Air/Mini. AgentMemory f5c174b2-46c7-4658-a572-daf20ebd7280.
- Peekaboo AX tree omits Finder context-menu items. Inspected screenshots provide real coordinates. Use global foreground --no-auto-focus for click/move; automatic focus dismisses menu. Do not treat IPC helper as menu proof. Four category actions, full8-action coverage, version bump and release remain pending. No public release or LS change.


## 2026-09-06 23:44 ET — Script runner and modal fixes verified

- Fixed an inherited-output-pipe hang in ScriptExecutor. A regression failed against the previous code after waiting 4.034 seconds for a background child. The shared runner now allows two seconds to drain both pipes after the command exits, then reports incomplete output. Running-command duration and output-memory limits are unchanged.
- Removed the editor's duplicate Bash/AppleScript runners. Editor Test now uses the same methods as Finder, drains large output concurrently and preserves the first selected path. Mini ScriptExecutorTests passed 30/30: outputs/monitor-tests/20260907T032343.491008Z-26533-2f96f927/receipt.json; workflow 665c2965af6aff30b0e7824dad9a693e.
- Actual editor Test produced the expected background-output error and a successful selected-folder result. Result Close and editor Cancel worked. No custom action was saved or owner action executed.
- Custom Actions lacked a visible close control, although Escape worked. Added native Done; its actual AXIdentifier closeCustomActionsButton click closed the sheet. Error text is now bright white on its red background. Import/Export subtitle is complete.
- Final signed build/runtime workflow 37c70102cd90fc120f5c3d13fb0acad4 passed. Clean inspected screenshots: 23-38-03 (Done), 23-39-54 (expanded sidebar), 23-42-13 (final error); 23-35-06 proves successful editor output. All are private QA, under infra/SaneProcess/outputs/portfolio-review-20260906/click-settings-visual on both machines.
- runner-and-modal-verification.json records source hashes, tests and visual verdicts. Five source/test files are identical on Air/Mini. Final runtime receipt outputs/runtime-logs/20260907T033652Z-20260906-30840-ejhaq6/receipt.json stopped at 2026-09-07T03:43:17.094240Z with app_exited; app and owned log processes are absent.
- Shared AgentMemory fact 495992ce-c3f9-4c8a-8057-929534dd1773 records the fixes, superseding the initial pending bug. Full eight-action Finder workflow, release gates, version bump and public release remain open. These app changes are not yet committed or released. Broad portfolio goal remains active.

## 2026-09-06 23:08 ET — GitHub defaults fixed; direct-main release pending CI

- Owner explicitly requested correct default GitHub tokens on both machines and verified direct-main pushes instead of new PRs. Both default gh logins were refreshed with native gh auth login using already-approved cached credentials. Separate fresh gh api user calls with GH_TOKEN, GITHUB_TOKEN and GH_CONFIG_DIR removed returned MrSaneApps on both. No authorization prompt or security ACL change. Receipts: github-default-auth.json on each host, with the peer receipt copied as github-default-auth-mini.json on Air and github-default-auth-air.json on Mini under the portfolio output directory.
- SaneClick caption is now corrected on both machines: complete 1 custom action text replaces the truncated redundant subtitle. Signed canonical workflow eeaf44dd11bfa17feff7bbc5b82f8944 passed build; clean Mini screenshot22:59:32 was inspected. Normal Quit ended its live log at03:00:40.107007Z/app_exited. Updated settings-visual-verification.json and screenshot are saved on both hosts. Full eight-action workflow and public release remain open.
- SaneCite branch67339ce35e4bf88a0bf78150641243bc4973789f is clean and pushed. Previous722e605 full CI passed; latest CI34078513417 is in progress. Latest change reuses an already-published parser image by immutable digest, rejects malformed inventory and validates image source/manifest before Worker deployment. Twenty-one delivery tests passed, and the archived actual image passes the pre-deployment validator.
- After exact latest-head full CI succeeds, push reviewed branch commits directly to main and observe canonical production deployment. PR8 already exists and should close when commits land. Target is safely dormant configuration, not customer activation. Source guard prevents status/selfcheck/old crons/dashboard warming from starting expensive work; campaign readiness still rejects dormant mode. No pricing, campaign or billing changes.
- Historical parser mismatch cause remains uncertain: saved rollout completed23:06:59Z before failed health check23:07:19–23:08:23Z. New authenticated cheap health proof binds the serving Worker before expensive checks, addressing the previous missing evidence. Do not call the historical mismatch confirmed fixed or claim active parser/model quality from a dormant release.
- Shared AgentMemory c4186f45-7c94-484a-af2b-e7252f2e76a5/revision1270 records credential and caption completion. Broad portfolio goal stays active; other native/iPad, LS and full machine reconciliation remain open.

## 2026-09-06 22:20 ET — Settings proof saved; remaining main caption

- Native license-sized workspace regression passed 1/1 after correcting the test to yield for SwiftUI mounting; original assertions remain intact. Canonical workflow 0ebdb354b8e09d40a18d817d6a184c0a. Initial synchronous fixture failed and is retained as evidence.
- Final signed native workflow 098ba9054636292aa2d536e4a4391cb9 showed the main window at 1040x772 and after resize to 800x650. White counts and wrapped descriptions are visible. One custom-actions subtitle still truncates; shorten the redundant wording and inspect a fresh build before clearing that main view.
- All five settings pages and scrolled General/About bottoms were inspected. Actual Refresh returned Extension Active; paid License was recognized; both Donate hearts are pink. Nine-image receipt and screenshots match both hosts at infra/SaneProcess/outputs/portfolio-review-20260906/click-settings-visual/settings-visual-verification.json.
- Normal Quit ended final runtime capture at 2026-09-07T02:08:19.065827Z with app_exited. No Click test app/log remains active. Full Finder action coverage and public release are still open; current modified 1.3.3 must be version-bumped before release.

## 2026-09-06 21:54 ET active SaneClick visual repair

- Canonical shared60176f3 signed build initially reopened main at520x712 and visibly crushed action names/descriptions (private screenshot click-settings-visual/codex-shot-2026-09-06_21-43-12.png). Cause: LicenseGateView fits520px native canvas; ContentView lacked the existing shared workspace release. Added saneWindowContentSize1040x720,hugging:false and wrapped descriptions. Actual next signed workflowf8a1bed6dfcd64cacf11a50254c47a8d/main AX1040x772 and inspected21:48:12 shows complete descriptions. Live capture apps/SaneClick/outputs/runtime-logs/20260907T014713Z-20260906-95949-x7g3p1 remains active, deadline02:47:13Z; currentPID96195.
- Three dependency pins and four settings scrollbars upgraded, folder paths wrap. Native General top/bottom inspected900x592; actual Refresh returned Extension Active; all five original monitored folders remain visible. Paid license recognized automatically at startup. No Finder restart, folder delete, action toggle or script execution performed.
- Sidebar subtitle wrap/white counts prepared but not in current runtime. Actual NSWindow regression added to existing VisualVerificationRenderTests/workspaceReleasesLicenseSizedWindow; tests and final sidebar build/visual proof PENDING. Source edits match both machines. One intermediate edit assertion stopped before SettingsView because two row types own successGreen; corrected scoped CategoryRow edit after inspection. Backups and scoped manifests under click-settings-visual.
- Launch guard stale messages wrongly instructed automatic TCC reset; five comment/message corrections applied on both machines while preserving existing host differences. Mini dispatcher tests20/20 passed in launch-guard-message-tests.log. No guard logic changed.
- AgentMemory Hosts closure save timed out after300s; durability unconfirmed, no repeat save. Hosts closure handoffs and five-image receipts are saved on both machines. Need repair/verify memory service before claiming shared memory updated.
- Sibling scan: SaneSync also swaps LicenseGateView into main scene and has no saneWindowContentSize call; inspect native sizing in that lane. Clip uses a separate gate window; Video/Sales have no LicenseGateView call. Portfolio remains active and incomplete.

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

## 2026-09-03 - Website dirties classified and committed (Mini)

- Read ~/AGENTS.md and SaneClick AGENTS.md first. Mini HEAD was 4daa323 (8/18, matches live 1.3.3 source).
- Per-file verdicts, all coherent later website work, committed as 7c4e04e (not pushed):
  - guides.html, 5 how-to pages, privacy.html: keep, og-image-20260827 + handle @MrSaneApps only.
  - index.html: keep, same meta updates plus downloadUrl and trial CTAs 1.3.2 to 1.3.3 plus desktop-nav Donate button (sponsors/MrSaneApps replaces desktop trial CTA; mobile/hero/pricing trial CTAs kept).
  - docs/404.html (new, minimal valid 404): keep.
  - docs/images/og-image-20260827.png + docs/og-image.png (new, identical md5 f776e8e5, 1200x630 PNG; root copy is a scraper fallback): keep.
  - docs/appcast.xml: shipped 8/18 publish state, left untouched (still dirty in tree by design).
- Nothing reverted; no file looked accidental or broken.
- release_preflight re-run read-only: RED (exit 1). Blockers: customer-UI receipt older than 12h plus missing outputs artifacts; local branch ahead of origin/main (unpushed 7c4e04e); upgrade-path proof receipt missing; live email worker serves 1.3.2 bundle build 1302 vs live appcast 1.3.3/1303; 1 uncommitted file (appcast.xml, by design); 10 pending customer emails. No deploy run: re-publish of identical source explicitly not wanted.
