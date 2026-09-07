# SaneClick Architecture

> [README](README.md) · [ARCHITECTURE](ARCHITECTURE.md) · [DEVELOPMENT](DEVELOPMENT.md) · [PRIVACY](PRIVACY.md) · [SECURITY](SECURITY.md)

Last updated: 2026-02-02

## Purpose

SaneClick is a macOS app + Finder Sync extension that adds curated and custom actions to the Finder right-click menu. The host app manages scripts and settings; the extension renders menus and triggers execution.

## Non-goals

- No cloud sync or analytics for script data.
- No background daemon beyond the Finder Sync extension.
- No direct modification of Finder state outside the Finder Sync API.

## System Context

- **Host app**: SwiftUI app that manages scripts, categories, and updates.
- **Finder Sync extension**: Builds the context menu and triggers script execution.
- **App Group container**: Shared storage and IPC between host + extension.
- **Sparkle**: Update checks via appcast.
- **No GitHub DMG**: DMGs are hosted on Cloudflare R2, not in GitHub.

## Architecture Principles

- Shared data lives in the App Group container so both targets see the same source of truth.
- Extension is read-only on script data; host app owns edits and broadcasts changes.
- File-based IPC (with locking) is favored over direct cross-process calls.
- Fail safe: if App Group is unavailable, fall back to Application Support.

## Core Components

| Component | Responsibility | Key Files |
|---|---|---|
| ScriptStore | Load/save scripts + categories; notifies extension on change | `SaneClick/Services/ScriptStore.swift` |
| ScriptExecutor | Executes bash/AppleScript/Automator workflows | `SaneClick/Services/ScriptExecutor.swift` |
| UpdateService | Sparkle updater wrapper | `SaneClick/Services/UpdateService.swift` |
| FinderSync | Finder context menu + execution trigger | `SaneClickExtension/FinderSync.swift` |
| Script models | Script types, filters, categories | `SaneClick/Models/*` |

## Data and Persistence

- **Scripts**: `scripts.json` in App Group container `M78L6FXD48.group.com.saneclick.app`. Fallback: `~/Library/Application Support/SaneClick/scripts.json`.
- **Categories**: `categories.json` in the same container (same fallback path).
- **Execution requests**: `pending_execution.json` + `.execution.lock` in App Group container.
- **Backups**: ScriptStore writes `*.backup.json` and `*.corrupted.json` when needed.

## Key Flows

### Script Edit -> Extension Menu Refresh
1. User edits scripts in the host app.
2. ScriptStore writes `scripts.json` and posts `com.saneclick.scriptsChanged`.
3. Finder Sync extension rebuilds the menu on next `menu(for:)` call.

### Finder Context Menu -> Script Execution
1. Finder Sync builds the menu from `scripts.json` and current selection.
2. User clicks an item; extension writes `pending_execution.json`.
3. Extension posts `com.saneclick.executeScript` via DistributedNotificationCenter.
4. Host app ScriptExecutor reads request, locks, validates, and executes.
5. Result is posted to UI via `ScriptExecutor.executionCompletedNotification`.

## State Machines

### Finder Menu Rendering

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> MenuRequested: Finder asks for menu
  MenuRequested --> ScriptsLoaded: read scripts.json
  ScriptsLoaded --> MenuRendered: filter + build menu
  MenuRendered --> Idle
  MenuRequested --> EmptyMenu: no scripts or read failure
  EmptyMenu --> Idle
```

| State | Meaning | Entry | Exit |
|---|---|---|---|
| Idle | Waiting for Finder request | default | menu(for:) |
| MenuRequested | Finder asks for context menu | menu(for:) | scripts loaded |
| ScriptsLoaded | Scripts loaded and filtered | loadScripts() | menu rendered |
| MenuRendered | Menu returned to Finder | menu(for:) return | idle |
| EmptyMenu | Fallback menu (settings only) | load failure | idle |

### Script Execution IPC

```mermaid
stateDiagram-v2
  [*] --> Waiting
  Waiting --> RequestWritten: extension writes file
  RequestWritten --> Notified: distributed notification
  Notified --> Processing: host reads + locks
  Processing --> Running: execute script
  Running --> ResultPosted: notify UI
  ResultPosted --> Waiting
  Processing --> Ignored: stale/duplicate request
  Ignored --> Waiting
```

| State | Meaning | Entry | Exit |
|---|---|---|---|
| Waiting | No pending request | default | pending_execution.json |
| RequestWritten | Request file exists | extension write | notification |
| Notified | Host is signaled | notification | host read |
| Processing | Lock + validate request | ScriptExecutor | run/ignore |
| Running | Script running (bash/osascript/automator) | execute() | result |
| ResultPosted | UI notified | post notification | waiting |
| Ignored | Duplicate or expired request | validation | waiting |

## Permissions and Privacy

- Finder Sync extension must be enabled in System Settings.
- Treat `pluginkit` as the source of truth when debugging extension enablement. `FIFinderSyncController.isExtensionEnabled` has returned false while the extension was enabled, so do not auto-open System Settings or mark setup broken from that API alone.
- Script execution runs on the Mac. Aggregate first-use/activation and update/license counts are disclosed in PRIVACY.md; do not describe the product as having no telemetry.
- Update checks use Sparkle.

## Build and Release Truth

- **Single source of truth**: `.saneprocess` in the project root.
- **Build/test**: `./scripts/SaneMaster.rb verify` (no raw xcodebuild).
- **Release**: `./scripts/SaneMaster.rb release` (delegates to SaneProcess `release.sh`).
- **Signed ZIP archives**: uploaded to Cloudflare R2 (not committed to GitHub).
- **Appcast**: Sparkle reads `SUFeedURL` from `SaneClick/Info.plist` (saneclick.com).
- **App Store posture**: App Store builds should rely on monitored folders, security-scoped bookmarks, app groups, and Finder Sync entitlements. Avoid scripting/temp-file workarounds or external purchase/support donation surfaces in Store builds.

## Testing Strategy

- Unit tests in `Tests/`.
- Use `./scripts/SaneMaster.rb verify` for build + tests.

## Risks and Tradeoffs

- Finder Sync menu caching can make updates appear stale if script change signals fail.
- App Group container access is required for consistent host/extension behavior.
- Script execution relies on system tools (`/bin/bash`, `/usr/bin/osascript`, `/usr/bin/automator`).

### Public guide claims | Updated: 2026-09-07 | TTL: 90d

- Trace customer-facing image claims through ScriptExecutor.execute, AppStoreNativeAction.requiresNativeRuntime and AppStoreNativeActionExecutor+Media. Built-in image actions execute natively on direct and Store builds; retained sips text identifies catalog actions and does not describe their current runtime.
- Remove Photo Info writes a unique _clean sibling. Originals retain their metadata. The writer omits source metadata dictionaries; the encoder may add technical fields. JPEG inputs produce JPEG and other accepted inputs PNG; orientation is baked into pixels. Re-encoding does not promise identical quality, color, size or an empty metadata container.
- Existing AppStoreNativeActionMediaTests.removePhotoInfoDropsMetadata proves GPS/UserComment/camera make/model removal. Conversion tests and actual Finder JPEG proof cover separate conversion behavior. Do not turn this into a claim that every format and metadata field has been independently tested.
- Apple's current [Finder Rename guide](https://support.apple.com/guide/mac-help/rename-files-folders-and-disks-on-mac-mchlp1144/mac) documents text replacement and numbered formats. The [Preview conversion guide](https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac) explicitly supports selecting multiple sidebar images for export. The [location guide](https://support.apple.com/guide/preview/see-where-a-photo-was-taken-prvw19865/mac) documents Show Location Info. These primary sources replace unsupported negative comparisons in the old guides.
- Keep guide cards, SEO metadata and article copy aligned. Describe the user's result and limits; avoid unsupported competitor limitations or promises that a successful batch notification proves every file changed.
