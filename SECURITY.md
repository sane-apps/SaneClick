# Security Policy

> [README](README.md) · [ARCHITECTURE](ARCHITECTURE.md) · [DEVELOPMENT](DEVELOPMENT.md) · [PRIVACY](PRIVACY.md) · [SECURITY](SECURITY.md)

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Security Model

### App Sandbox
SaneClick uses a Finder Extension architecture:
- Direct-download build is **not** sandboxed (required: it runs user-authored
  Finder scripts and updates via Sparkle outside the sandbox)
- Mac App Store build **is** sandboxed (`SaneClick-AppStore.entitlements`)
- Finder extension has limited entitlements
- Scripts execute in user context (not elevated), with no helpers and no
  elevated privileges

### Script Execution
SaneClick runs user-defined scripts on files:
- Scripts run with the user's permissions
- No elevated privileges are used
- Scripts run with the user's full file access; the Finder selection only
  determines which paths are passed in

### Code Signing
- Signed with Developer ID: MrSaneApps (M78L6FXD48)
- Notarized by Apple
- Hardened runtime enabled

### Data Security
- Scripts are stored locally in app container
- No cloud sync or remote storage
- License keys are stored in Keychain; no passwords, tokens, or keys in
  UserDefaults or plaintext files

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **DO NOT** open a public issue
2. Email security concerns to: hi@saneapps.com
3. Or use GitHub's private vulnerability reporting

### What to Include
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline
- **Initial Response**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix Timeline**: Depends on severity
  - Critical: Patch release within 48 hours
  - High: Patch release within 1 week
  - Medium: Next regular release
  - Low: Backlog for future release

### Recognition
Security researchers who report valid vulnerabilities will be:
- Credited in release notes (unless they prefer anonymity)
- Added to SECURITY.md acknowledgments

## Security Best Practices for Users

1. **Download from official sources only**
   - saneclick.com

2. **Verify code signature**
   ```bash
   codesign -dv --verbose=4 /Applications/SaneClick.app
   # Should show: Developer ID Application: MrSaneApps (M78L6FXD48)
   ```

3. **Keep the app updated**
   - Enable auto-update checks
   - Security fixes are prioritized

4. **Review scripts before running**
   - Especially imported scripts
   - Scripts have full user-level access to files

## Known Security Considerations

### Script Execution Risks
SaneClick executes user-defined scripts. A malicious script could:
- Delete or modify files
- Access sensitive data
- Execute arbitrary commands

**Mitigations**:
- Scripts run with user permissions (not root)
- Review all scripts before running
- Be cautious with imported scripts
- Test scripts on non-critical files first

### Imported Script Risks
When importing scripts:
- Scripts may contain malicious code
- No automatic safety validation is performed

**Mitigations**:
- Only import scripts from trusted sources
- Review script content before importing
- Test in a safe environment first

## Acknowledgments

Thanks to the following for responsible disclosure:
- (No reports yet)
