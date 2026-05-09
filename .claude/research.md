# Research Cache

> Active research index only. Durable Finder Sync/App Store findings were promoted
> to Serena/memory on 2026-05-04. Older raw notes remain recoverable in git history.

## Finder Sync Product Model | Updated: 2026-05-04 | Status: promoted | TTL: 90d
- Finder Sync API/state-machine/menu rebuild rules are durable architecture, not active scratch.
- Promoted to Serena memory `research_compaction_2026_05_04.md`.

## App Store Review / Metadata Lessons | Updated: 2026-05-04 | Status: promoted | TTL: 90d
- App Store-safe action catalog, entitlement/review lessons, and metadata clarity rules were promoted to Serena/memory.
- Refresh from live App Store Connect before acting on old March review assumptions.

## Pricing Guardrail / SaneUI Drift | Updated: 2026-04-15 | Status: expired | TTL: 7d
- Expired 2026-04-22.
- Reopen only if current verify or release preflight reproduces the pricing/SaneUI drift.

## Remote SaneUI Source-Build Recovery | Updated: 2026-04-14 | Status: expired | TTL: 7d
- Expired 2026-04-21.
- Reopen only with fresh Mini verify evidence.

## Shared SaneUI Menu Recovery Compile APIs | Updated: 2026-05-09 | Status: verified | TTL: 7d
- Local Mini source research after two verify failures: SaneClick `ScriptStore` loads scripts/categories in `init()` and exposes private `loadScripts()`, not a public `loadIfNeeded()`. Do not call `scriptStore.loadIfNeeded()` from settings.
- Current SaneUI `SaneLoginItemPolicy` exposes `scheduleDefaultLaunchAtLoginPrompt(appName:)` and `offerDefaultLaunchAtLoginIfNeeded(appName:)`; the older `enableByDefaultIfNeeded(isFirstLaunch:)` call site is stale.
- SaneUI shared menu/settings support was committed and pushed as `ce1df3c` on `sane-apps/SaneUI.git` main, so SaneClick `Package.resolved` must resolve SaneUI to `ce1df3c2b03d8ade3b300e907fbcf37320a847bc` or newer before using `SaneStandardMenu`.
- Verification target after this research: rerun Mini `./scripts/SaneMaster.rb verify --timeout 1200` from SaneClick after syncing the compile fixes and package pin.
