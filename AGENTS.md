# SaneClick Agent Instructions

Follow `~/AGENTS.md` first (cross-LLM policy source of truth). This file carries SaneClick-specific facts.

Philosophy: `~/SaneApps/meta/Brand/NORTH_STAR.md`

## What Is This

Finder context menu customization for macOS — ready-to-use actions for the Finder right-click menu. Website: saneclick.com (`docs/`, Cloudflare Pages).

## Source Of Truth

- Product behavior and setup: `README.md`
- Development workflow: `DEVELOPMENT.md`
- Architecture: `ARCHITECTURE.md`
- Privacy/security claims: `PRIVACY.md`, `SECURITY.md`
- Release history: `CHANGELOG.md`
- Project config: `project.yml` (XcodeGen)
- Shared UI: `~/SaneApps/infra/SaneUI/`; hooks/tooling: `~/SaneApps/infra/SaneProcess/`

Product roster (canonical): macOS = SaneHosts, SaneClip, SaneClick, SaneSales, SaneVideo; iOS = SaneScan (iPhone/iPad only), SaneLot; SaaS = SaneCite. SaneBar is retired (free + OSS, never advertised as a peer product).

## Project Structure

| Path | Purpose |
|------|---------|
| `SaneClick/App/` | App entry, AppDelegate |
| `SaneClick/Models/` | Script, Category models |
| `SaneClick/Services/` | ScriptExecutor, ConfigStore/ScriptStore |
| `SaneClick/Views/` | SwiftUI settings UI (ContentView is the main surface) |
| `SaneClickExtension/` | Finder Sync Extension (`FinderSync.swift`, extension `Info.plist`) |
| `Tests/` | Unit tests |
| `docs/` | Cloudflare Pages site, appcast |

## Critical Implementation Notes

1. **Extension bundle must be inside the app bundle** — the build system handles this.
2. **App Group required** — `group.com.saneclick.app` for shared data.
3. **User must enable the extension** — System Settings > Privacy & Security > Extensions > Finder.
4. **Don't cache menus** — rebuild `NSMenu` on each `menu(for:)` call.
5. **Script execution happens in the host app** — the extension sends a notification, the app executes.
6. **Always live-verify the real Finder menu** after menu changes; a green build is not proof the menu renders.

## Build, Test, Release (Mini-first)

- Canonical route: run `ruby scripts/SaneMaster.rb verify` on the Mac Mini (build + tests).
- Local Xcode builds on the Air are an explicitly-approved fallback only.
- Release: `bash ~/SaneApps/infra/SaneProcess/scripts/release.sh --project <path> --full` (ships ZIPs).

## Testing Strategy

All interactive elements need accessibility identifiers (e.g. `.accessibilityIdentifier("addScriptButton")`). If automation can't find a control, the UX is broken — fix the design first.

## Research & Memory

- Past bugs/learnings: agentmemory `memory_recall` / `memory_smart_search` + Claude file memory.
- Apple frameworks: `apple-docs` MCP. Library docs: `plugin:context7:context7` (resolve-library-id → query-docs). GitHub search: `gh` CLI.
- RAM/process hygiene: follow the RAM-discipline rule in `~/AGENTS.md` (never bulk-kill agent processes).
