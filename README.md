# SaneScript

> Custom scripts in your Finder right-click menu

![SaneScript Main Window](docs/screenshots/main-window.png)

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

SaneScript puts your scripts directly in Finder's context menu. Simple to set up, simple to use.

- **Three Script Types**: Bash, AppleScript, Automator workflows
- **Smart Filtering**: Show scripts only for specific file types
- **Categories**: Organize scripts into groups
- **Test Before Save**: Run scripts on files before committing
- **Import/Export**: Share scripts as JSON

**100% local. Free and open source. We never see your data.**

---

## Features

| Feature | Description |
|---------|-------------|
| **Script Types** | Bash, AppleScript, and Automator workflows |
| **File Type Filters** | Show scripts only for specific file extensions |
| **Script Categories** | Organize scripts into custom groups |
| **Test Scripts** | Run scripts on selected files before saving |
| **Import/Export** | Share scripts as JSON files |
| **Search** | Filter scripts by name or content |
| **Keyboard Shortcuts** | Full keyboard navigation (Cmd+N, Cmd+Shift+N) |

---

## Requirements

- macOS 14.0+
- Xcode 16.0+ (for building from source)
- XcodeGen (for project generation)

---

## Installation

### Download

[Download the latest release](https://github.com/sane-apps/SaneScript/releases/latest) and move `SaneScript.app` to Applications.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/sane-apps/SaneScript.git
cd SaneScript

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project SaneScript.xcodeproj -scheme SaneScript build
```

### Enable the Extension

1. Open SaneScript
2. Go to **System Settings > Privacy & Security > Extensions > Finder**
3. Enable **SaneScript**

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
SaneScript/
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
