# SaneScript

Custom Finder context menu scripts for macOS.

![SaneScript Main Window](docs/screenshots/main-window.png)

## Features

- **Script Types**: Bash, AppleScript, and Automator workflows
- **File Type Filters**: Show scripts only for specific file extensions
- **Script Categories**: Organize scripts into custom groups
- **Test Scripts**: Run scripts on selected files before saving
- **Import/Export**: Share scripts as JSON files
- **Search**: Filter scripts by name or content
- **Keyboard Shortcuts**: Full keyboard navigation support

## Requirements

- macOS 14.0+
- Xcode 16.0+ (for building)
- XcodeGen (for project generation)

## Building

1. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

2. Build with Xcode or command line:
   ```bash
   xcodebuild -project SaneScript.xcodeproj -scheme SaneScript build
   ```

3. Run tests:
   ```bash
   xcodebuild -project SaneScript.xcodeproj -scheme SaneScript test
   ```

## Installation

1. Build the app
2. Move `SaneScript.app` to Applications
3. Launch SaneScript
4. Enable the Finder extension in System Settings > Privacy & Security > Extensions > Finder

## Usage

1. **Add Scripts**: Click the + button and choose "New Script"
2. **Configure**: Set name, type, content, and file filters
3. **Test**: Use the Test button to try your script on files
4. **Organize**: Create categories and drag scripts between them
5. **Use**: Right-click files in Finder to see your scripts

### Script Variables

- **Bash**: `$1`, `$2`, etc. for file paths, or `$@` for all
- **AppleScript**: Use `item 1 of argv` to access paths
- **Automator**: File paths are passed via standard input

## Architecture

```
SaneScript/
├── SaneScript/              # Host app (settings UI)
│   ├── App/                 # App entry
│   ├── Models/              # Script, Category models
│   ├── Services/            # ScriptExecutor, ScriptStore
│   └── Views/               # SwiftUI views
├── SaneScriptExtension/     # Finder Sync Extension
│   ├── FinderSync.swift     # FIFinderSync subclass
│   └── Info.plist           # Extension config
├── Tests/                   # Unit tests
└── project.yml              # XcodeGen config
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## License

MIT License - See LICENSE file for details
