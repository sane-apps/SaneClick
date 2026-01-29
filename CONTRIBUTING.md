# Contributing to SaneClick

Thanks for your interest in contributing to SaneClick!

---

## What is SaneClick?

SaneClick adds custom context menu scripts to Finder. Create Bash, AppleScript, or Automator workflows that appear when you right-click files.

**Part of the Sane Apps family** - See [saneapps.com](https://saneapps.com)

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/sane-apps/SaneClick.git
cd SaneClick

# Generate Xcode project
xcodegen generate

# Build and test
xcodebuild -project SaneClick.xcodeproj -scheme SaneClick build
xcodebuild -project SaneClick.xcodeproj -scheme SaneClick test
```

---

## Development Environment

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 16+**
- **XcodeGen** (`brew install xcodegen`)

### Architecture

```
SaneClick/
├── SaneClick/              # Host app (settings UI)
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ScriptStore
│   └── Views/               # SwiftUI views
├── SaneClickExtension/     # Finder Sync Extension
└── Tests/                   # Unit tests
```

---

## Coding Standards

### Swift
- **Swift 5.9+** features encouraged
- **@Observable** instead of @StateObject
- **Swift Testing** framework for tests

### Extension Guidelines
- Keep the Finder extension lightweight
- Shared data goes through App Groups
- Handle script execution errors gracefully

---

## Making Changes

### Before You Start

1. Check existing issues for similar work
2. For major features, open an issue first to discuss

### Pull Request Process

1. **Fork** the repository
2. **Create a branch** from `main`
3. **Make your changes** following the coding standards
4. **Run tests**: Full test suite must pass
5. **Submit PR** with clear description

---

## Testing the Extension

1. Build and run SaneClick from Xcode
2. Enable the extension: System Settings > Privacy & Security > Extensions > Finder
3. Create a test script in SaneClick
4. Right-click a file in Finder to verify

---

## Questions?

- Open an issue on GitHub
- See the [Sane Apps documentation](https://saneapps.com)
