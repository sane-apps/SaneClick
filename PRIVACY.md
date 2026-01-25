# Privacy Policy

**Last updated: January 19, 2026**

SaneScript is designed with privacy as a core principle. This document explains how the app handles your data.

## Our Philosophy

**Your data stays on your device.** Period.

## Data Collection

### What We DON'T Collect
- No analytics or telemetry
- No crash reports sent externally
- No usage statistics
- No personal information
- No network requests

### What Stays Local
- **Scripts** - Stored in your Finder sync folder
- **Preferences** - Stored in macOS defaults system

## Permissions Used

### File System Access
- **Finder Sync Extension** - To display script status in Finder
- **Application Support** - To store configuration

### System Services
- **Finder Extension** - For Finder integration

## Third-Party Services

SaneScript uses no third-party services, SDKs, or analytics.

## Auto-Updates

When enabled, SaneScript checks for updates via Sparkle framework:
- Connects to `sanescript.com/appcast.xml`
- Only checks for version information
- No personal data transmitted

## Your Rights

You have full control:
- View all stored data in Application Support folder
- Disable all optional features
- Uninstall completely with no traces

## Complete Uninstall

To remove all SaneScript data:
```bash
# Remove application
rm -rf /Applications/SaneScript.app

# Remove preferences
defaults delete com.sanescript.app

# Remove application data
rm -rf ~/Library/Application\ Support/SaneScript
rm -rf ~/Library/Caches/com.sanescript.app
```

## Contact

Questions about privacy? Open an issue on [GitHub](https://github.com/sane-apps/SaneScript/issues).

## Changes

Any changes to this policy will be documented in the CHANGELOG and noted in release notes.
