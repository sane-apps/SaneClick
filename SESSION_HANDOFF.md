# Session Handoff - February 3, 2026

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
