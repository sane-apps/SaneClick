# SaneClick Development Guide (SOP)

**Version 1.0** | Last updated: 2026-01-20

> **SINGLE SOURCE OF TRUTH** for all Developers and AI Agents.

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

## This Has Burned You

Real failures from past sessions. Don't repeat them.

| Mistake | What Happened | Prevention |
|---------|---------------|------------|
| **Guessed API** | Assumed API exists. It doesn't. 20 min wasted. | `verify_api` first |
| **Skipped xcodegen** | Created file, "file not found" for 20 minutes | `xcodegen generate` after new files |
| **Kept guessing** | Same error 4 times. Finally checked apple-docs MCP. | Stop at 2, investigate |
| **Deleted "unused" file** | Periphery said unused, but ServiceContainer needed it | Grep before delete |
| **Extension not loading** | Changed extension target but didn't rebuild host app | Rebuild both targets |
| **Finder menu stale** | Cached menu items from previous session | Don't cache menus - rebuild on each `menu(for:)` call |
| **App Group mismatch** | Extension couldn't read shared data | Verify `group.com.saneclick.app` in both targets |

<!-- ADD PROJECT-SPECIFIC BURNS ABOVE -->

**The #1 differentiator**: Skimming this SOP = 5/10 sessions. Internalizing it = 8+/10.

**"If you skim you sin."** — The answers are here. Read them.

---

## Quick Start for AI Agents

**New to this project? Start here:**

1. **Read Rule #0 first** (Section "The Rules") - It's about HOW to use all other rules
2. **All files stay in project** - NEVER write files outside `~/SaneApps/apps/SaneClick/` unless user explicitly requests it
3. **Use XcodeBuildMCP for build/test** - Set session defaults, then use `build_macos`, `test_macos`
4. **Self-rate after every task** - Rate yourself 1-10 on SOP adherence (see Self-Rating section)

Bootstrap runs automatically via SessionStart hook. If it fails, check XcodeBuildMCP defaults.

**Key Commands:**
```bash
xcodegen generate                    # Regenerate project after new files
# Then use XcodeBuildMCP:
mcp__XcodeBuildMCP__build_macos      # Build
mcp__XcodeBuildMCP__test_macos       # Test
mcp__XcodeBuildMCP__build_run_macos  # Build + launch
```

**XcodeBuildMCP Session Defaults (set at session start):**
```
mcp__XcodeBuildMCP__session-set-defaults:
  projectPath: ~/SaneApps/apps/SaneClick/SaneClick.xcodeproj
  scheme: SaneClick
  arch: arm64
```

---

## The Rules

### #0: NAME THE RULE BEFORE YOU CODE

✅ DO: State which rules apply before writing code
❌ DON'T: Start coding without thinking about rules

```
RIGHT: "Uses Apple API → Rule #2: VERIFY BEFORE YOU TRY"
RIGHT: "New file → Rule #9: NEW FILE? GEN THAT PILE"
WRONG: "Let me just code this real quick..."
```

### #1: STAY IN YOUR LANE

✅ DO: Save all files inside `~/SaneApps/apps/SaneClick/`
❌ DON'T: Create files outside project without asking

### #2: VERIFY BEFORE YOU TRY

✅ DO: Check apple-docs MCP before using any Apple API
❌ DON'T: Assume an API exists from memory or web search

**Especially important for:**
- `FIFinderSync` API (Finder Sync Extension)
- `NSFileProviderExtension` callbacks
- App Group / shared container APIs

### #3: TWO STRIKES? INVESTIGATE

✅ DO: After 2 failures → stop, follow **Research Protocol** (see section below)
❌ DON'T: Guess a third time without researching

### #4: GREEN MEANS GO

✅ DO: Fix all test failures before claiming done
❌ DON'T: Ship with failing tests

### #5: XCODEBUILDMCP OR DISASTER

✅ DO: Use XcodeBuildMCP for all build/test operations
❌ DON'T: Use raw xcodebuild without session defaults

### #6: BUILD, KILL, LAUNCH, LOG

✅ DO: Run full sequence after every code change
❌ DON'T: Skip steps or assume it works

```bash
# Kill any running instance
killall SaneClick 2>/dev/null || true

# Build and run
mcp__XcodeBuildMCP__build_run_macos
```

### #7: NO TEST? NO REST

✅ DO: Every bug fix gets a test that verifies the fix
❌ DON'T: Use placeholder or tautology assertions (`#expect(true)`)

### #8: BUG FOUND? WRITE IT DOWN

✅ DO: Document bugs in TodoWrite immediately
❌ DON'T: Try to remember bugs or skip documentation

### #9: NEW FILE? GEN THAT PILE

✅ DO: Run `xcodegen generate` after creating any new file
❌ DON'T: Create files without updating project

### #10: FIVE HUNDRED'S FINE, EIGHT'S THE LINE

| Lines | Status |
|-------|--------|
| <500 | Good |
| 500-800 | OK if single responsibility |
| >800 | Must split |

### #11: TOOL BROKE? FIX THE YOKE

✅ DO: If XcodeBuildMCP fails, check session defaults first
❌ DON'T: Work around broken tools

### #12: TALK WHILE I WALK

✅ DO: Use subagents for heavy lifting, stay responsive to user
❌ DON'T: Block on long operations

---

## Self-Rating (MANDATORY)

After each task, rate yourself. Format:

```
**Self-rating: 7/10**
✅ Used apple-docs MCP, ran full cycle
❌ Forgot to run xcodegen after new file
```

| Score | Meaning |
|-------|---------|
| 9-10 | All rules followed |
| 7-8 | Minor miss |
| 5-6 | Notable gaps |
| 1-4 | Multiple violations |

---

## Research Protocol (STANDARD)

This is the standard protocol for investigating problems. Used by Rule #3, Circuit Breaker, and any time you're stuck.

### Tools to Use (ALL of them)

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Task agents** | Explore codebase, analyze patterns | "Where is X used?", "How does Y work?" |
| **apple-docs MCP** | Verify Apple APIs exist and usage | Any Apple framework API, especially FIFinderSync |
| **context7 MCP** | Library documentation | Third-party packages |
| **WebSearch/WebFetch** | Solutions, patterns, best practices | Error messages, architectural questions |
| **Grep/Glob/Read** | Local investigation | Find similar patterns, check implementations |
| **memory MCP** | Past bug patterns, architecture decisions | "Have we seen this before?" |
| **RESEARCH.md** | Project-specific API research | Finder Sync Extension API, state machine |

### Research Output → Plan

After research, present findings in this format:

```
## Research Findings

### What I Found
- [Tool used]: [What it revealed]
- [Tool used]: [What it revealed]

### Root Cause
[Clear explanation of why the problem occurs]

### Proposed Fix

[Rule #X: NAME] - specific action
[Rule #Y: NAME] - specific action
...

### Verification
- [ ] XcodeBuildMCP test_macos passes
- [ ] Manual test: [specific check]
```

---

## Circuit Breaker Protocol

The circuit breaker is an automated safety mechanism that **blocks Edit/Bash/Write tools** after repeated failures.

### When It Triggers

| Condition | Threshold | Meaning |
|-----------|-----------|---------|
| **Same error 3x** | 3 identical | Stuck in loop, repeating same mistake |
| **Total failures** | 5 any errors | Flailing, time to step back |

### Recovery Flow

```
CIRCUIT BREAKER TRIPS
         │
         ▼
┌─────────────────────────────────────────────┐
│  1. READ ERRORS                             │
│     Review what failed                      │
├─────────────────────────────────────────────┤
│  2. RESEARCH (use ALL tools above)          │
│     - What API am I misusing?               │
│     - Has this bug pattern happened before? │
│     - What does the documentation say?      │
│     - Check RESEARCH.md for Finder Sync     │
├─────────────────────────────────────────────┤
│  3. PRESENT SOP-COMPLIANT PLAN              │
│     - State which rules apply               │
│     - Show what research revealed           │
│     - Propose specific fix steps            │
├─────────────────────────────────────────────┤
│  4. USER APPROVES PLAN                      │
└─────────────────────────────────────────────┘
         │
         ▼
    EXECUTE APPROVED PLAN
```

**Key insight**: Being blocked is not failure—it's the system working. The research phase often reveals the root cause that guessing would never find.

---

## Plan Format (MANDATORY)

Every plan must cite which rule justifies each step. No exceptions.

**Format**: `[Rule #X: NAME] - specific action with file:line or command`

### DISAPPROVED PLAN

```
## Plan: Fix Bug

### Steps
1. Clean build
2. Fix the issue
3. Rebuild and verify

Approve?
```

**Why rejected:**
- No `[Rule #X]` citations - can't verify SOP compliance
- No tests specified (violates Rule #7)
- Vague "fix" without file:line references

### APPROVED PLAN

```
## Plan: Fix [Bug Description]

### Bugs to Fix
| Bug | File:Line | Root Cause |
|-----|-----------|------------|
| [Description] | [File.swift:50] | [Root cause] |

### Steps

[Rule #5: USE XCODEBUILDMCP] - Clean build with `mcp__XcodeBuildMCP__clean`

[Rule #7: TESTS FOR FIXES] - Create tests:
  - Tests/[TestFile].swift: `test[FeatureName]()`

[Rule #6: FULL CYCLE] - Verify fixes:
  - `mcp__XcodeBuildMCP__test_macos`
  - `killall SaneClick`
  - `mcp__XcodeBuildMCP__build_run_macos`
  - Manual: [specific check]

[Rule #4: GREEN BEFORE DONE] - All tests pass before claiming complete

Approve?
```

---

## Project Structure

```
SaneClick/
├── SaneClick/              # Host app (settings UI)
│   ├── App/                 # App entry, AppDelegate
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ScriptStore
│   └── Views/               # SwiftUI views
├── SaneClickExtension/     # Finder Sync Extension (CRITICAL)
│   ├── FinderSync.swift     # FIFinderSync subclass
│   └── Info.plist           # Extension config
├── Tests/                   # Unit tests
├── Resources/               # Assets, entitlements
├── docs/                    # Cloudflare Pages, appcast
├── RESEARCH.md              # All research + state machine
├── project.yml              # XcodeGen config
└── CLAUDE.md                # Quick reference
```

---

## Finder Sync Extension Notes

**Critical implementation details:**

| Aspect | Requirement |
|--------|-------------|
| Bundle location | Extension bundle MUST be inside host app bundle |
| App Group | `group.com.saneclick.app` for shared UserDefaults |
| User enablement | Users must manually enable in System Settings > Extensions > Finder |
| Menu caching | NEVER cache menus - rebuild `NSMenu` on each `menu(for:)` call |
| Script execution | Extension sends notification → host app executes script |

**Testing the extension:**
1. Build both targets (host app + extension)
2. Launch host app
3. Ensure extension is enabled in System Settings
4. Right-click files in Finder to see context menu

---

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| FinderSync | SaneClickExtension/FinderSync.swift | Provides context menu items in Finder |
| ScriptStore | SaneClick/Services/ScriptStore.swift | Manages script configurations |
| ScriptExecutor | SaneClick/Services/ScriptExecutor.swift | Runs scripts safely |
| ContentView | SaneClick/Views/ContentView.swift | Main settings UI |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Ghost beeps / no launch | `xcodegen generate` |
| Phantom build errors | `mcp__XcodeBuildMCP__clean` then rebuild |
| "File not found" after new file | `xcodegen generate` |
| Tests failing mysteriously | Clean build, then test |
| Extension not showing in Finder | Check System Settings > Extensions > Finder |
| Stale context menu | Rebuild both targets, restart Finder (`killall Finder`) |
| App Group data not syncing | Verify entitlements match in both targets |
| Extension crashes on launch | Check Console.app for crash logs |

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

1. Set XcodeBuildMCP session defaults (see Quick Start)
2. Read `RESEARCH.md` if unfamiliar with Finder Sync API
3. Search memory MCP: `project: "SaneClick"`
4. Kill stale processes: `killall SaneClick 2>/dev/null || true`
5. Use subagents for heavy work, verify their output
