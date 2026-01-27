# SaneScript - Claude Code Instructions

> Finder context menu customization for macOS

---

## Sane Philosophy

```
┌─────────────────────────────────────────────────────┐
│           BEFORE YOU SHIP, ASK:                     │
│                                                     │
│  1. Does this REDUCE fear or create it?             │
│  2. Power: Does user have control?                  │
│  3. Love: Does this help people?                    │
│  4. Sound Mind: Is this clear and calm?             │
│                                                     │
│  Grandma test: Would her life be better?            │
│                                                     │
│  "Not fear, but power, love, sound mind"            │
│  — 2 Timothy 1:7                                    │
└─────────────────────────────────────────────────────┘
```

→ Full philosophy: `~/SaneApps/meta/Brand/NORTH_STAR.md`

---

## Project Location

| Path | Description |
|------|-------------|
| **This project** | `~/SaneApps/apps/SaneScript/` |
| **Save outputs** | `~/SaneApps/apps/SaneScript/outputs/` |
| **Screenshots** | `~/Desktop/Screenshots/` (label with project prefix) |
| **Research doc** | `RESEARCH.md` (single source of truth) |
| **Shared UI** | `~/SaneApps/infra/SaneUI/` |
| **Hooks/tooling** | `~/SaneApps/infra/SaneProcess/` |

**Sister apps:** SaneBar, SaneClip, SaneVideo, SaneSync, SaneHosts, SaneAI

---

## Where to Look First

| Need | Check |
|------|-------|
| Build/test commands | XcodeBuildMCP (see defaults below) |
| Project structure | `project.yml` (XcodeGen config) |
| API research | `RESEARCH.md` |
| Past bugs/learnings | `.claude/memory.json` or MCP memory |
| Finder Sync API | `RESEARCH.md` → Finder Sync Extension API section |
| State machine | `RESEARCH.md` → State Machine section |

---

## XcodeBuildMCP Session Defaults

Set these at session start:

```
mcp__XcodeBuildMCP__session-set-defaults:
  projectPath: ~/SaneApps/apps/SaneScript/SaneScript.xcodeproj
  scheme: SaneScript
  arch: arm64
```

Then use: `build_macos`, `test_macos`, `build_run_macos`

---

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -project SaneScript.xcodeproj -scheme SaneScript -configuration Debug build

# Run tests
xcodebuild -project SaneScript.xcodeproj -scheme SaneScript test

# Or use XcodeBuildMCP after setting defaults
```

---

## Project Structure

```
SaneScript/
├── SaneScript/              # Host app (settings UI)
│   ├── App/                 # App entry, AppDelegate
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ConfigStore
│   └── Views/               # SwiftUI views
├── SaneScriptExtension/     # Finder Sync Extension
│   ├── FinderSync.swift     # FIFinderSync subclass
│   └── Info.plist           # Extension config
├── Tests/                   # Unit tests
├── Resources/               # Assets, entitlements
├── docs/                    # Cloudflare Pages, appcast
├── RESEARCH.md              # All research + state machine
├── project.yml              # XcodeGen config
└── CLAUDE.md                # This file
```

---

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| FinderSync | SaneScriptExtension/ | Provides context menu items |
| ScriptStore | SaneScript/Services/ | Manages script configs |
| ScriptExecutor | SaneScript/Services/ | Runs scripts safely |
| ContentView | SaneScript/Views/ | Main settings UI |

---

## Critical Implementation Notes

1. **Extension bundle must be inside app bundle** - Build system handles this
2. **App Group required** - `group.com.sanescript.app` for shared data
3. **User must enable extension** - System Settings > Privacy & Security > Extensions > Finder
4. **Don't cache menus** - Rebuild `NSMenu` on each `menu(for:)` call
5. **Script execution in host app** - Extension sends notification, app executes

---

## Research Protocol

Always update `RESEARCH.md` with findings. Before implementing:

1. Check `RESEARCH.md` → API section
2. Search memory MCP: `project: "SaneScript"`
3. Apple docs: `mcp__apple-docs__`
4. GitHub: `mcp__github__search_code`
5. Context7: `mcp__context7__query-docs`

---

## Testing Strategy

All interactive elements need accessibility identifiers:

```swift
.accessibilityIdentifier("addScriptButton")
.accessibilityIdentifier("scriptList")
.accessibilityIdentifier("saveButton")
```

If automation can't find it → UX is broken → fix design first.

---

## Session Start Checklist

1. `caffeinate -d -i -m -s &` - Prevent sleep
2. Kill orphaned Claude processes: `pkill -f 'claude.*--resume' 2>/dev/null || true`
3. Read `RESEARCH.md` if unfamiliar
4. Set XcodeBuildMCP defaults
5. Use subagents for heavy work, verify their output

---

## Memory Management

MacBook Air has limited RAM. Orphaned Claude subagents can accumulate and cause OOM kills.

**Check memory:** `top -l 1 -o MEM | head -12`

**Kill orphans:** `pkill -f 'claude.*--resume'`

**Warning signs:**
- Free RAM < 1GB
- Multiple `2.1.19` processes in top
- Heavy swap activity (check vm_stat)
