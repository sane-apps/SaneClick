# SaneClick

> 50+ ready-to-use actions for your Finder right-click menu

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
- Xcode 16.0+ (for building from source)
- XcodeGen (for project generation)

---

## Installation

### Buy the DMG ($5)

[Buy SaneClick](https://sane.lemonsqueezy.com/buy/saneclick) — Signed, notarized, ready to use. Supports sustainable open source development.

### Build from Source (Free)

```bash
# Clone the repository
git clone https://github.com/sane-apps/SaneClick.git
cd SaneClick

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project SaneScript.xcodeproj -scheme SaneScript build
```

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

```
SaneClick/
├── SaneScript/              # Host app (settings UI)
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ScriptStore
│   ├── Views/               # SwiftUI views
│   └── Theme/               # Brand colors
├── SaneScriptExtension/     # Finder Sync Extension
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

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

Part of the [Sane Apps](https://saneapps.com) family.
