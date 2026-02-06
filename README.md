# SaneClick

> 50+ ready-to-use actions for your Finder right-click menu

[![GitHub stars](https://img.shields.io/github/stars/sane-apps/SaneClick?style=flat-square)](https://github.com/sane-apps/SaneClick/stargazers)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen)](https://www.apple.com/macos)

> **⭐ Star this repo if it's useful!** · **[💰 Buy for $5](https://saneclick.com)** · Keeps development alive

![SaneClick Main Window](docs/screenshots/main-window.png)

**🔒 No spying · 💵 No subscription · 🛠️ Actively maintained**

---

## The Problem

Every time you right-click in Finder, you're stuck with Apple's limited context menu. Want to convert an image? Open in Terminal? Run a quick script? You have to leave Finder, open another app, navigate back to your file, and do it manually.

### Why Can't You Fix It Yourself?

macOS has Services and Folder Actions, but they require Automator knowledge or AppleScript expertise. Most people give up before they start.

### Why Alternatives Fail You

The "easy" solutions cost $10-15, require subscriptions, or haven't been updated since 2019. Some are abandonware. Others are overkill.

---

## The Sane Solution

SaneClick gives you **50+ ready-to-use actions** — no scripting required. Browse by category, toggle on what you need, done.

- **Curated Library**: 50+ pre-built actions organized by category
- **One-Click Install**: Toggle actions on/off instantly
- **Smart Filtering**: Actions appear only for matching file types
- **Custom Scripts**: Power users can write Bash, AppleScript, or Automator workflows
- **Categories**: Essentials, Files & Folders, Images & Media, Coding, Advanced

**$5 for the signed DMG. Build from source for free. 100% local. We never see your data.**

---

## Features

| Feature | Description |
|---------|-------------|
| **50+ Pre-built Actions** | Copy paths, convert images, open in Terminal, and more |
| **5 Categories** | Essentials, Files & Folders, Images & Media, Coding, Advanced |
| **Smart Filtering** | Actions appear only for matching file types |
| **One-Click Install** | Toggle actions on/off instantly |
| **Custom Scripts** | Write Bash, AppleScript, or Automator workflows |
| **Test Before Save** | Run scripts on files before committing |
| **Import/Export** | Share scripts as JSON files |

---

## Requirements

- macOS 14.0+
- Apple Silicon (arm64) only
- Xcode 16.0+ (for building from source)
- XcodeGen (project generation; SaneMaster runs it for you)

---

## Installation

### Buy the DMG ($5)

[Buy SaneClick](https://saneclick.com) — Signed, notarized, ready to use. Supports sustainable open source development.
DMGs are hosted on Cloudflare (not attached to GitHub releases).

### Build from Source (Free)

**Building from source?** Consider [buying the DMG for $5](https://saneclick.com) to support continued development. Open source doesn't mean free labor.

```bash
# Clone the repository
git clone https://github.com/sane-apps/SaneClick.git
cd SaneClick

# Build + test (preferred)
./scripts/SaneMaster.rb verify

# Launch
./scripts/SaneMaster.rb launch
```
SaneMaster runs XcodeGen when needed; only run `xcodegen generate` manually if you add files and want to refresh immediately.

### Enable the Extension

1. Open SaneClick
2. Go to **System Settings > Privacy & Security > Extensions > Finder**
3. Enable **SaneClick**

---

## Usage

1. **Add Scripts**: Click the + button and choose "New Script"
2. **Configure**: Set name, type, content, and file filters
3. **Test**: Use the Test button to try your script on files
4. **Organize**: Create categories and assign scripts
5. **Use**: Right-click files in Finder to see your scripts

### Script Variables

| Type | Variables |
|------|-----------|
| **Bash** | `$1`, `$2`, etc. for file paths, or `$@` for all |
| **AppleScript** | `item 1 of argv` to access paths |
| **Automator** | File paths via standard input |

---

## Architecture

See [ARCHITECTURE.md](../ARCHITECTURE.md) for the full system overview and state machines.

```
SaneClick/
├── SaneClick/              # Host app (settings UI)
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ScriptStore
│   ├── Views/               # SwiftUI views
│   └── Theme/               # Brand colors
├── SaneClickExtension/     # Finder Sync Extension
│   └── FinderSync.swift     # Context menu provider
├── Tests/                   # Unit tests
└── docs/                    # Website
```

---

## Our Promise

> *"For God has not given us a spirit of fear, but of power and of love and of a sound mind."*
> — 2 Timothy 1:7

| Pillar | Meaning |
|--------|---------|
| **⚡ Power** | Your data stays on your device. No cloud, no tracking. |
| **❤️ Love** | Built to serve you. No dark patterns or manipulation. |
| **🧠 Sound Mind** | Calm, focused design. Does one thing well. |

---

## Contributing

Before opening a PR:
1. **[⭐ Star the repo](https://github.com/sane-apps/SaneClick)** (if you haven't already)
2. Read [CONTRIBUTING.md](CONTRIBUTING.md)
3. Open an issue first to discuss major changes

---

## Support

**[⭐ Star the repo](https://github.com/sane-apps/SaneClick)** if SaneClick helps you. Stars help others discover quality open source.

**Cloning without starring?** For real bro? Gimme that star!

- 🐛 [Report a Bug](https://github.com/sane-apps/SaneClick/issues)
- 💡 [Request a Feature](https://github.com/sane-apps/SaneClick/issues)

---

## License

GPL v3 — see [LICENSE](LICENSE) for details.

---

Part of the [Sane Apps](https://saneapps.com) family.
