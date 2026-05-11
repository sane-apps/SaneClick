# Session Handoff — SaneClick

**Last updated:** 2026-05-11
**Current public version:** `1.1.6` (build `1106`)
**Next release candidate:** `1.1.7` (build `1107`)

## Current State

- 2026-05-11 SaneClick `#4` duplicate app-menu Settings item is fixed in the `1.1.7` release candidate, not publicly commented yet:
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
