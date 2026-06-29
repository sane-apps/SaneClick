# Changelog

All notable changes to SaneClick are documented here.

---

## [1.2.1] - 2026-06-29

Right-click actions now group into folders in the Finder menu, so the new tools
(Copy Text from Image, the PDF actions, and more) are easy to find instead of
buried at the bottom of a long list.

---

## [1.2.0] - 2026-06-28

New right-click actions:

- Copy Text from Image / Save Text from Image — pull the text out of a
  screenshot, photo, or scan, right from the menu. It runs on your Mac, no
  internet.
- Combine Images into PDF, Split PDF into Pages, and PDF to Images — quick PDF
  jobs without opening another app.
- More copy options — copy a file's URL, its name without the extension, its
  parent folder, or a ready-to-paste Markdown link.

New per-action settings:

- When done — choose to copy an action's result, show it in a window, or get it
  in a notification.
- Ask before running — get a confirmation before an action that moves, renames,
  or deletes files. It's on by default for those.

Right-click actions can now group into folders once you sort them into
categories.

Your license is now stored in the modern macOS keychain, so the app should stop
asking for keychain permission after updates. Existing licenses move over
automatically. (Direct download builds; the Mac App Store build was already
unaffected.)

---

## [1.1.12] - 2026-06-22

Pro is now free to try for 14 days. Basic remains included after the trial.

---

## [1.1.11] - 2026-06-22

Pro is now free to try for 14 days. Basic remains included after the trial.

---

## [1.1.10] - 2026-05-19

Fixes license-key paste reliability in activation and settings.

---

## [1.1.9] - 2026-05-11

Restores Finder action availability for direct-download installs, shows monitored-folder setup in the app, and keeps built-in actions organized after updates.

---

## [1.1.9] - 2026-05-11

Repairs fresh direct-download installs where Finder actions could be enabled in SaneClick but absent from Finder because no monitored folders were registered. Direct builds now expose monitored-folder setup, seed standard user folders on startup, preserve user folder choices, and clean up legacy duplicate built-in actions after library updates.

Fixes category and library Enable All reliability, repairs Finder right-click filtering for file-only and folder-only actions, and restores image conversion actions that use macOS `sips`.

---

## [1.1.8] - 2026-05-11

Fixes category and library Enable All reliability, repairs Finder right-click filtering for file-only and folder-only actions, and restores image conversion actions that use macOS `sips`.

---

## [1.1.7] - 2026-05-11

Shows a single Settings item in the app menu and keeps the settings shortcut behavior consistent.

---

## [1.1.6] - 2026-05-09

Adds Settings, License, About, and bug report access from the Dock and menu bar menus; prevents hiding both app access points at once; improves Finder extension permission scoping; and makes the settings/reporting flow easier to recover from.

---

## [1.1.5] - 2026-04-15

Updates the Pro pricing copy so onboarding, locked actions, and upgrade prompts all show the current $9.99 one-time unlock consistently.

---

## [1.1.4] - 2026-04-03

Fixes Finder extension status refresh so the app updates correctly after returning from System Settings, and repairs the macOS App Store signing lane for the Finder Sync target.

---

## [1.1.3] - 2026-04-01

Adds a Finder footer toggle, restores custom action management in the Mac app, and improves built-in action icon rendering.

---

## [1.1.1] - 2026-03-16

Adds in-app bug reporting with diagnostics from Settings, and improves support and settings consistency.

---

## [1.0.4] - 2026-02-23

Corrective release: align binary metadata with appcast and App Store pipeline.

---

## [1.0.3] - 2026-02-03

### Added
- **Context-aware actions**: Show only relevant items based on selection and file types
- **Import/Export window**: Reliable script import/export flow
- **Background execution**: Running actions no longer steals focus
- **Optional notifications**: Get notified when actions complete
- **Menu bar icon toggle**: Show or hide the menu bar icon
- **Dock visibility toggle**: Control whether SaneClick appears in the Dock
- **Update menu**: Check for updates from within the app

---

## [1.0.2] - 2026-01-29

### Added
- **50+ Actions**: Curated library of Finder context menu actions
- **Script Testing**: Test scripts before saving
- **Security Hardening**: Safe shell patterns for all library scripts

### Changed
- **Rebrand to SaneClick**: Fresh identity, same great functionality
