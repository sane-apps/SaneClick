# SaneScript Roadmap

> **Goal**: Outshine all competitors while maintaining semiotic design principles, keyboard navigability, and testability.

---

## Competitive Analysis

### Competitor Feature Matrix

| Feature | SaneScript | Context Menu ($9.99) | FinderEx (Free) | Service Station ($14.99) | FiScript (Abandoned) |
|---------|------------|---------------------|-----------------|-------------------------|---------------------|
| **Price** | Free/MIT | $9.99 | Free/GPL | $14.99 | Free/MIT |
| **Active Development** | ✓ | ✓ | ✓ | ✓ | ✗ (2022) |
| **Script Types** | | | | | |
| - Bash/Shell | ✓ | ✓ | ✓ | ✓ | ✓ |
| - AppleScript | ✓ | ? | ✓ | ✓ | ✓ |
| - Automator | ✓ | ✗ | ✓ | ✓ | ✗ |
| - Shortcuts.app | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Organization** | | | | | |
| - Categories/Groups | ✗ | ✗ | ✓ | ✓ | ✗ |
| - File Type Filters | ✗ | ✗ | ✓ | ✓ | ✗ |
| - Search Scripts | ✗ | ? | ✗ | ? | ✗ |
| **Execution** | | | | | |
| - Keyboard Shortcuts | ✗ | ✓ | ✗ | ✗ | ✗ |
| - Test Script Button | ✗ | ? | ✗ | ? | ✗ |
| - Execution Feedback | ✗ | ? | ✗ | ? | ✗ |
| **Data** | | | | | |
| - Import/Export | ✗ | ? | ✓ (YAML) | ? | ✗ |
| - System-wide Config | ✗ | ✗ | ✓ | ✗ | ✗ |
| - Sync (iCloud) | ✗ | ? | ✗ | ✗ | ✗ |
| **UI/UX** | | | | | |
| - Native SwiftUI | ✓ | ✗ | ✗ | ✗ | ✗ |
| - Keyboard Nav | Partial | ? | ✗ | ? | ✗ |
| - Accessibility | Partial | ? | ✗ | ? | ✗ |
| - Drag Reorder | ✓ | ? | ? | ? | ✗ |

### Competitive Gaps (Opportunities)

1. **No competitor has Shortcuts.app integration** - Modern macOS users expect this
2. **No competitor has proper keyboard navigation** - Power users want this
3. **No competitor has built-in script testing** - Developers need this
4. **No competitor has execution feedback/history** - Users want to know what happened
5. **No competitor has iCloud sync** - Multi-Mac users need this

### SaneScript Advantages to Preserve

1. **Free and Open Source** - vs Context Menu ($9.99), Service Station ($14.99)
2. **Native SwiftUI** - Modern, fast, accessible by default
3. **Clean Architecture** - Observable pattern, testable services
4. **Semiotic Design** - Consistent iconography, clear affordances

---

## Design Principles (Non-Negotiable)

From RESEARCH.md, all features MUST follow:

| Principle | Implementation |
|-----------|----------------|
| **Semiotic Icons** | SF Symbols only, universal meaning |
| **Affordance = Signifier** | If it looks clickable, it must be |
| **Keyboard Navigable** | Every action via keyboard |
| **Flat UI Hierarchy** | No deep nesting, max 2 levels |
| **Accessibility IDs** | Every interactive element tagged |
| **Testable** | Protocol-based, mockable services |

---

## Roadmap Phases

### Phase 0: Foundation (COMPLETED)
> Fix what's broken before adding features

| Task | Priority | Effort | Status |
|------|----------|--------|--------|
| Fix sandbox/App Group issues | P0 | Done | ✓ |
| Enable extension via pluginkit | P0 | Done | ✓ |
| Save learnings to memory | P0 | Done | ✓ |
| Extension status detection (real) | P1 | S | ✓ |
| Delete confirmation dialog | P1 | S | ✓ |
| Execution error feedback | P1 | M | ✓ |
| Unit tests for ScriptStore | P1 | M | ✓ |
| Unit tests for ExtensionStatus | P1 | M | ✓ |

### Phase 1: Parity (COMPLETED)
> Match competitor features users expect

| Feature | Why | Effort | Status |
|---------|-----|--------|--------|
| **File Type Filters** | Filter scripts by extension (*.jpg, *.pdf) | M | ✓ |
| **Script Categories** | Organize scripts into groups | M | ✓ |
| **Test Script Button** | Run script on sample files from editor | M | ✓ |
| **Import/Export** | Share scripts as JSON | S | ✓ |
| **Duplicate Script** | Copy existing script | S | ✓ |
| **Search Scripts** | Filter script list by name/content | S | ✓ |

### Phase 2: Differentiation (Stand Out)
> Features no competitor has

| Feature | Why | Effort | Differentiation |
|---------|-----|--------|-----------------|
| **Shortcuts.app Integration** | Modern macOS automation | L | **First to market** |
| **Global Keyboard Shortcuts** | Trigger scripts without Finder | M | Context Menu has partial |
| **Execution History** | Log of what ran, when, result | M | **No competitor has this** |
| **Script Templates Gallery** | Pre-built useful scripts | M | Better onboarding |
| **Live Output Preview** | See script output before saving | M | **No competitor has this** |
| **Undo/Redo** | Recover deleted scripts | S | Standard UX |

### Phase 3: Delight (Polish)
> Make it exceptional

| Feature | Why | Effort |
|---------|-----|--------|
| **iCloud Sync** | Scripts across Macs | L |
| **Menu Bar Quick Access** | Run frequent scripts from menu bar | M |
| **Syntax Highlighting** | Better script editing | M |
| **Script Variables** | `{{filename}}`, `{{date}}` placeholders | M |
| **Conditional Logic** | Run different scripts based on file type | L |
| **Onboarding Flow** | Guide new users through setup | S |

---

## Phase 1 Detailed Spec

### 1.1 File Type Filters

**User Story**: As a user, I want scripts to only appear for certain file types.

**Implementation**:
```swift
struct Script {
    // Existing fields...
    var fileExtensions: [String]  // e.g., ["jpg", "png", "gif"]
    var matchMode: MatchMode      // .any, .all, .none
}

enum MatchMode: String, Codable {
    case any      // Match if ANY extension matches
    case all      // Match if ALL selected files match
    case none     // No filtering (current behavior)
}
```

**UI**:
- Add "File Types" section in ScriptEditorView
- Tag-style input for extensions
- "Any file" toggle (default)

**Accessibility ID**: `fileTypeFilter`

### 1.2 Script Categories

**User Story**: As a user, I want to organize scripts into groups.

**Implementation**:
```swift
struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var scriptIds: [UUID]
}
```

**UI**:
- Sidebar sections for categories
- Drag scripts between categories
- "Uncategorized" default category

**Keyboard**:
- `Cmd+N` new script
- `Cmd+Shift+N` new category
- Arrow keys navigate categories

### 1.3 Test Script Button

**User Story**: As a user, I want to test my script before saving.

**Implementation**:
- "Test" button in ScriptEditorView
- Opens file picker to select test files
- Shows output in sheet/popover
- Non-destructive (sandboxed preview)

**UI**:
```
[Cancel]  [Test ▶]  [Save]
```

**Accessibility ID**: `testScriptButton`

### 1.4 Import/Export

**Format**: JSON (our native) + YAML (FinderEx compatible)

**Export**:
- Single script → JSON file
- All scripts → ZIP with JSON + assets
- Category → JSON with scripts

**Import**:
- Drag JSON onto window
- File menu → Import
- Detect duplicates by name

---

## Testing Strategy

### Unit Tests (Phase 0-1)

| Component | Test Cases |
|-----------|------------|
| Script | Init, Codable, equality, validation |
| Category | Init, Codable, script management |
| ScriptStore | CRUD, persistence, notifications |
| ScriptExecutor | Bash, AppleScript, Automator execution |
| FileTypeFilter | Extension matching, match modes |

### UI Tests (Phase 1+)

| Flow | Test Cases |
|------|------------|
| Add Script | Create, validate, save, appears in list |
| Edit Script | Modify, save, changes persist |
| Delete Script | Confirm, delete, removed from list |
| Reorder | Drag, drop, order persists |
| Categories | Create, assign, filter |

### Integration Tests (Phase 2+)

| Scenario | Test Cases |
|----------|------------|
| Extension → Host | Notification received, script executes |
| Host → Extension | Config saved, extension sees update |
| Script Execution | Bash output, AppleScript result, errors |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Feature Parity** | Match FinderEx | Feature checklist |
| **Test Coverage** | >80% | Xcode coverage report |
| **Accessibility** | 100% interactive elements | Accessibility audit |
| **Keyboard Nav** | Every action has shortcut | Manual audit |
| **Performance** | <100ms menu build | Instruments profiling |
| **Crash Rate** | 0 crashes | Console logs |

---

## Next Actions

1. [ ] Fix extension status detection (hardcoded "Enabled")
2. [ ] Add delete confirmation dialog
3. [ ] Add execution error feedback (alert)
4. [ ] Write ScriptStore unit tests
5. [ ] Write ScriptExecutor unit tests
6. [ ] Implement File Type Filters
7. [ ] Implement Script Categories

---

*Last Updated: 2026-01-19*
