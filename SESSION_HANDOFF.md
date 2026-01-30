# Session Handoff - January 30, 2026

## Release Script Audit Fix (Jan 30)

### What Changed
Cross-project audit found `release.sh` was missing `<description>` tag in appcast template and had GitHub Releases upload instructions instead of Cloudflare R2.

### Round 1 Fixes
- Added `<description><![CDATA[...]]></description>` to appcast heredoc template
- Changed upload instructions to R2: `npx wrangler r2 object put sanebar-downloads/updates/...`
- Added `.meta` file output (VERSION, BUILD, SHA256, SIZE, SIGNATURE)
- Added FILE_SIZE to release info output

### Round 2 Fixes (Feature Parity)
- Added SUPublicEDKey/SUFeedURL verification (reads built Info.plist before shipping)
- Replaced hdiutil-only with create-dmg + hdiutil fallback

### Round 3 Fixes (Deep Verification)
- Moved FILE_SIZE outside `if [ -n "$SIGNATURE" ]` block (was scoped inside but used outside)

### Live Testing (Jan 30)
- SaneClick-1.0.2.dmg (1.7MB) signed with Sparkle EdDSA key → 88-char base64 signature PASS
- Full appcast XML rendered with correct `sparkle:version` (numeric BUILD_NUMBER) and `sparkle:shortVersionString` (semantic VERSION)
- No leading spaces in attribute values (heredoc confirmed clean)

### The Rule
- `sparkle:version` = BUILD_NUMBER (numeric) -- was already correct
- `sparkle:shortVersionString` = VERSION (semantic) -- was already correct
- Always use heredoc, never echo for appcast templates -- was already correct
- URL: `https://dist.saneclick.com/updates/SaneClick-{version}.dmg`

---

## 🚀 SaneClick Status Update
- **Identity Protected:** All tracked project files (`LICENSE`, `SECURITY.md`, `PRIVACY.md`) now use **MrSaneApps** alias.
- **Generic Signing:** Build configuration (`project.yml`, `release.sh`) now uses generic `"Developer ID Application"` string. Xcode resolves the correct certificate via Team ID (`M78L6FXD48`). No real name is hardcoded in the repo.
- **Rebranding Complete:** Finished the transition from `SaneScript` to `SaneClick`. Updated all internal bundle IDs, App Groups (`group.com.saneclick.app`), and notification names.
- **MCP Fixed:** Resolved `mcp_toolbox` connection error by disabling incompatible `tools.yaml` shell commands and providing a minimal valid configuration.

## ✅ Verification
- **Builds:** `xcodegen generate` and `xcodebuild` successful with generic signing.
- **Tests:** 61/61 unit tests passed (100%).
- **IPC:** Verified App Group consistency between host and extension.

## 🛠️ Next Steps
1. **LemonSqueezy:** Create SaneClick product ($5) and update the checkout link in `docs/index.html`.
2. **Video Demos:** Film real usage videos for all products to replace animated/mock demos.
3. **SaneClick Guides:** Expand the library to match SaneClip's depth (5+ guides).
4. **Final Folder Rename:** Consider renaming the root folder to `SaneClick` now that rebranding is solid.

## 📝 Critical Note
- **Git Identity:** Always use `MrSaneApps` for commits in this and related projects.
- **Signing Rule:** Use generic `"Developer ID Application"` in all SaneApps projects to protect identity.
