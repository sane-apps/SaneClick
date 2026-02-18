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

# Build + test (preferred)
./scripts/SaneMaster.rb verify

# Launch
./scripts/SaneMaster.rb launch
```

---

## Development Environment

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon (arm64) only**
- **Xcode 16+**
- **XcodeGen** (`brew install xcodegen`) — SaneMaster runs it when needed

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

1. Build and run with `./scripts/SaneMaster.rb launch`
2. Enable the extension: System Settings > Privacy & Security > Extensions > Finder
3. Create a test script in SaneClick
4. Right-click a file in Finder to verify

---

## Questions?

- Open an issue on GitHub
- See the [Sane Apps documentation](https://saneapps.com)

<!-- SANEAPPS_AI_CONTRIB_START -->
## Become a Contributor (Even if You Don't Code)

Are you tired of waiting on the dev to get around to fixing your problem?  
Do you have a great idea that could help everyone in the community, but think you can't do anything about it because you're not a coder?

Good news: you actually can.

Copy and paste this into Claude or Codex, then describe your bug or idea:

```text
I want to contribute to this repo, but I'm not a coder.

Repository:
https://github.com/sane-apps/SaneClick

Bug or idea:
[Describe your bug or idea here in plain English]

Please do this for me:
1) Understand and reproduce the issue (or understand the feature request).
2) Make the smallest safe fix.
3) Open a pull request to https://github.com/sane-apps/SaneClick
4) Give me the pull request link.
5) Open a GitHub issue in https://github.com/sane-apps/SaneClick/issues that includes:
   - the pull request link
   - a short summary of what changed and why
6) Also give me the exact issue link.

Important:
- Keep it focused on this one issue/idea.
- Do not make unrelated changes.
```

If needed, you can also just email the pull request link to hi@saneapps.com.

I review and test every pull request before merge.

If your PR is merged, I will publicly give you credit, and you'll have the satisfaction of knowing you helped ship a fix for everyone.
<!-- SANEAPPS_AI_CONTRIB_END -->
