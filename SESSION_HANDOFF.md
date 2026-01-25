# SaneScript Session Handoff

**Date**: 2026-01-24 (continued session)
**Session Focus**: Release infrastructure setup

---

## Completed Work

### Previous Session (same day)
1. **FIXED BUG-001** - File picker works via NSOpenPanel
2. **Full 14-perspective docs audit** completed
3. **Created website** - `docs/index.html` at script.saneapps.com
4. **Added .help() tooltips** - 8 key controls
5. **Created SaneColors.swift** - Brand color palette

### This Session - Release Infrastructure
6. **Added Sparkle dependency** - project.yml now includes Sparkle 2.8.0
7. **Created UpdateService.swift** - Wrapper for SPUStandardUpdaterController
8. **Added "Check for Updates" button** - In SettingsView About tab
9. **Generated EdDSA keypair** - Public key: `Sr8JFxaVIJ0bZfR0lmVBdCYFb+13DyuPYjfy4ivQ7/g=`
10. **Created appcast.xml** - In docs/ for Sparkle auto-updates
11. **Set up dist.saneapps.com** - DNS CNAME → sane-dist worker
12. **Updated sane-dist worker** - Added sanescript to ALLOWED_APPS, deployed
13. **Fixed Info.plist versions** - Now uses $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION)
14. **Fixed extension version mismatch** - Both targets now share version settings

---

## Infrastructure Status

| Component | Status | Details |
|-----------|--------|---------|
| **Sparkle** | ✅ Ready | EdDSA key in keychain, UpdateService.swift created |
| **Distribution Worker** | ✅ Deployed | dist.saneapps.com routes to sane-dist |
| **Appcast** | ✅ Created | docs/appcast.xml (needs signature after DMG build) |
| **Website** | ✅ Live | script.saneapps.com via GitHub Pages |
| **Build** | ✅ Passing | Clean debug build |

---

## Files Modified This Session

| File | Changes |
|------|---------|
| `project.yml` | +Sparkle pkg, +info properties, +version settings |
| `SaneScript/Services/UpdateService.swift` | NEW - Sparkle wrapper |
| `SaneScript/Views/SettingsView.swift` | +Check for Updates button |
| `SaneScript/Info.plist` | +SUPublicEDKey, version variables |
| `SaneScriptExtension/Info.plist` | Version variables |
| `docs/appcast.xml` | NEW - Sparkle feed |
| `docs/CNAME` | script.saneapps.com |
| `~/SaneApps/infra/sane-dist-worker/wrangler.toml` | +dist.saneapps.com route |

---

## Release Checklist (v1.0.1)

```
[x] Sparkle configured (SUFeedURL, SUPublicEDKey)
[x] UpdateService.swift created
[x] Check for Updates UI added
[x] appcast.xml skeleton created
[x] Distribution worker deployed
[x] Website live
[ ] Build Release DMG
[ ] Sign with Developer ID
[ ] Notarize with Apple
[ ] Staple notarization ticket
[ ] Sign DMG with Sparkle EdDSA key
[ ] Upload DMG to R2 bucket
[ ] Update appcast.xml with signature + file size
[ ] Set up Lemon Squeezy product ($5)
[ ] Test Sparkle update flow
```

---

## Key Files Reference

| Purpose | Location |
|---------|----------|
| Sparkle public key | project.yml line 116, Info.plist |
| Sparkle private key | macOS Keychain (auto-stored by generate_keys) |
| Appcast | docs/appcast.xml |
| Distribution | dist.saneapps.com/updates/SaneScript-{version}.dmg |
| Website | script.saneapps.com (GitHub Pages from docs/) |
| Release SOP | ~/SaneApps/infra/SaneProcess/templates/RELEASE_SOP.md |
| Full bootstrap | ~/SaneApps/infra/SaneProcess/templates/FULL_PROJECT_BOOTSTRAP.md |

---

## Quick Commands

```bash
# Build Release
xcodebuild archive \
  -project SaneScript.xcodeproj \
  -scheme SaneScript \
  -archivePath build/SaneScript.xcarchive \
  -configuration Release

# Create DMG (after archive)
hdiutil create -volname "SaneScript" \
  -srcfolder "build/export/SaneScript.app" \
  -ov -format UDZO \
  "releases/SaneScript-1.0.1.dmg"

# Notarize
xcrun notarytool submit releases/SaneScript-1.0.1.dmg \
  --keychain-profile "notarytool" --wait

# Sign for Sparkle (after notarization)
/path/to/sign_update releases/SaneScript-1.0.1.dmg

# Upload to R2 (use Cloudflare API)
```

---

## Current State

- **Version**: 1.0.1 (build 101)
- **Build**: ✅ Debug passes, Release untested
- **Ready for**: Release DMG build and distribution setup
