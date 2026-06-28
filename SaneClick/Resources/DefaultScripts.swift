import Foundation

/// Curated library of pre-built scripts for SaneClick
/// Organized by category for easy browsing and installation
enum ScriptLibrary {
    /// Script template for library items
    struct LibraryScript {
        let name: String
        let type: ScriptType
        let content: String
        let icon: String
        let appliesTo: AppliesTo
        let fileExtensions: [String]
        let extensionMatchMode: ExtensionMatchMode
        let minSelection: Int
        let maxSelection: Int?
        let category: ScriptCategory
        let description: String
        let outputMode: ScriptOutputMode
        let confirmBeforeRun: Bool

        init(
            name: String,
            type: ScriptType,
            content: String,
            icon: String,
            appliesTo: AppliesTo,
            fileExtensions: [String],
            extensionMatchMode: ExtensionMatchMode = .all,
            minSelection: Int = 1,
            maxSelection: Int? = nil,
            category: ScriptCategory,
            description: String,
            outputMode: ScriptOutputMode = .standard,
            confirmBeforeRun: Bool = false
        ) {
            self.name = name
            self.type = type
            self.content = content
            self.icon = icon
            self.appliesTo = appliesTo
            self.fileExtensions = fileExtensions
            self.extensionMatchMode = extensionMatchMode
            self.minSelection = minSelection
            self.maxSelection = maxSelection
            self.category = category
            self.description = description
            self.outputMode = outputMode
            self.confirmBeforeRun = confirmBeforeRun
        }

        /// Convert to a Script model
        func toScript() -> Script {
            Script(
                name: name,
                type: type,
                content: content,
                icon: icon,
                appliesTo: appliesTo,
                fileExtensions: fileExtensions,
                extensionMatchMode: extensionMatchMode,
                minSelection: minSelection,
                maxSelection: maxSelection,
                outputMode: outputMode,
                confirmBeforeRun: confirmBeforeRun
            )
        }
    }

    /// Categories for organizing library scripts
    /// Color semantics from SaneApps Brand Guidelines:
    /// - Blue: Primary/essential (trustworthy, main features)
    /// - Purple: Technical/developer (coding, automation)
    /// - Pink: Creative/visual (images, media)
    /// - Orange: Warning/advanced (power user, be careful)
    /// - Green: Success/safe (file management, constructive)
    enum ScriptCategory: String, CaseIterable {
        case universal = "Essentials"
        case organization = "Files & Folders"
        case designer = "Images & Media"
        case developer = "Coding"
        case powerUser = "Advanced"

        var icon: String {
            switch self {
            case .universal: "star.fill"
            case .organization: "folder.fill"
            case .designer: "photo.on.rectangle.angled"
            case .developer: "chevron.left.forwardslash.chevron.right"
            case .powerUser: "wrench.and.screwdriver.fill"
            }
        }

        var description: String {
            switch self {
            case .universal: "Everyday actions everyone needs"
            case .organization: "Sort, rename, and manage files"
            case .designer: "Resize, convert, and edit images"
            case .developer: "Tools for writing code"
            case .powerUser: "Compression, hashing, system tools"
            }
        }

        /// Semantic color name for SwiftUI
        /// Meanings: blue=essential, green=safe, pink=creative, teal=technical, orange=warning
        var colorName: String {
            switch self {
            case .universal: "blue"
            case .organization: "green"
            case .designer: "pink"
            case .developer: "purple"
            case .powerUser: "orange"
            }
        }
    }

    /// Internal (not private) so the split-out catalog in ScriptCatalog.swift,
    /// which is an `extension ScriptLibrary` in a separate file, can reference it.
    static let imageExtensions = [
        "jpg", "jpeg", "png", "heic", "tiff", "gif", "bmp", "webp"
    ]

    // MARK: - Universal Scripts

    static let universalScripts: [LibraryScript] = [
        LibraryScript(
            name: "Copy Path",
            type: .bash,
            content: "printf '%s\\n' \"$@\" | pbcopy",
            icon: "doc.on.clipboard",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .universal,
            description: "Copy the full file path to clipboard"
        ),
        LibraryScript(
            name: "Copy Filename",
            type: .bash,
            content: "basename -- \"$1\" | tr -d '\\n' | pbcopy",
            icon: "textformat",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Copy just the filename to clipboard"
        ),
        LibraryScript(
            name: "Open in Terminal",
            type: .bash,
            content: """
            if [ -d "$1" ]; then
                open -a Terminal "$1"
            else
                open -a Terminal "$(dirname -- "$1")"
            fi
            """,
            icon: "terminal",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Open Terminal at this location"
        ),
        LibraryScript(
            name: "New Text File",
            type: .bash,
            content: """
            if [ -d "$1" ]; then
                touch -- "$1/Untitled.txt"
            else
                touch -- "$(dirname -- "$1")/Untitled.txt"
            fi
            """,
            icon: "doc.badge.plus",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Create a new empty text file"
        ),
        LibraryScript(
            name: "Show Hidden Files",
            type: .bash,
            content: """
            CURRENT=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null)
            if [ "$CURRENT" = "YES" ] || [ "$CURRENT" = "TRUE" ] || [ "$CURRENT" = "1" ]; then
                defaults write com.apple.finder AppleShowAllFiles NO
            else
                defaults write com.apple.finder AppleShowAllFiles YES
            fi
            killall Finder
            """,
            icon: "eye",
            appliesTo: .container,
            fileExtensions: [],
            category: .universal,
            description: "Show or hide hidden files in Finder"
        ),
        LibraryScript(
            name: "Delete .DS_Store Files",
            type: .bash,
            content: """
            if [ -d "$1" ]; then
                find "$1" -name '.DS_Store' -type f -delete
            else
                find "$(dirname "$1")" -name '.DS_Store' -type f -delete
            fi
            osascript -e 'display notification "Cleaned up .DS_Store files" with title "SaneClick"'
            """,
            icon: "trash",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Clean up hidden Mac system files in folder",
            confirmBeforeRun: true
        ),
        LibraryScript(
            name: "Duplicate with Timestamp",
            type: .bash,
            content: """
            for f in "$@"; do
                FILENAME=$(basename -- "$f")
                EXTENSION="${FILENAME##*.}"
                BASENAME="${FILENAME%.*}"
                TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                DIR=$(dirname -- "$f")
                if [ "$EXTENSION" = "$FILENAME" ]; then
                    cp -rn -- "$f" "$DIR/${BASENAME}_${TIMESTAMP}"
                else
                    cp -rn -- "$f" "$DIR/${BASENAME}_${TIMESTAMP}.${EXTENSION}"
                fi
            done
            """,
            icon: "doc.on.doc",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .universal,
            description: "Make a copy with date and time in the name"
        ),
        LibraryScript(
            name: "Get File Info",
            type: .bash,
            content: """
            INFO=$(stat -f "Size: %z bytes%nCreated: %SB%nModified: %Sm%nPermissions: %Sp" -- "$1")
            BASENAME=$(basename -- "$1")
            osascript - "$INFO" "$BASENAME" <<'APPLESCRIPT'
            on run argv
                set fileInfo to item 1 of argv
                set fileName to item 2 of argv
                display dialog fileInfo with title ("File Info: " & fileName) buttons {"OK"} default button "OK"
            end run
            APPLESCRIPT
            """,
            icon: "info.circle",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Show file size, dates, and permissions"
        ),
        LibraryScript(
            name: "Reveal in Finder",
            type: .applescript,
            content: """
            set targetFile to POSIX file (item 1 of argv)
            tell application "Finder"
                reveal targetFile
                activate
            end tell
            """,
            icon: "folder.badge.questionmark",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Reveal item in a new Finder window"
        ),
        LibraryScript(
            name: "Make Executable",
            type: .bash,
            content: """
            for f in "$@"; do
                chmod +x -- "$f"
            done
            osascript -e 'display notification "File(s) made executable" with title "SaneClick"'
            """,
            icon: "gearshape.2",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .universal,
            description: "Allow file to be run as a program"
        ),
        LibraryScript(
            name: "Copy as File URL",
            type: .bash,
            content: "# Runs natively via SaneClick (Copy as File URL).",
            icon: "link",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .universal,
            description: "Copy the item as a file:// URL"
        ),
        LibraryScript(
            name: "Copy Filename without Extension",
            type: .bash,
            content: "# Runs natively via SaneClick (Copy Filename without Extension).",
            icon: "textformat.alt",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Copy the filename without its extension"
        ),
        LibraryScript(
            name: "Copy Parent Folder Path",
            type: .bash,
            content: "# Runs natively via SaneClick (Copy Parent Folder Path).",
            icon: "folder",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Copy the path of the enclosing folder"
        ),
        LibraryScript(
            name: "Copy as Markdown Link",
            type: .bash,
            content: "# Runs natively via SaneClick (Copy as Markdown Link).",
            icon: "text.badge.plus",
            appliesTo: .allItems,
            fileExtensions: [],
            maxSelection: 1,
            category: .universal,
            description: "Copy the item as a Markdown link"
        )
    ]

    // MARK: - Developer Scripts

    static let developerScripts: [LibraryScript] = [
        LibraryScript(
            name: "Git Init",
            type: .bash,
            content: """
            (
                cd "$1" || exit 1
                git init
                echo "# $(basename -- "$1")" > README.md
                echo ".DS_Store" > .gitignore
                echo "node_modules/" >> .gitignore
                git add .
                git commit -m "Initial commit"
            )
            osascript -e 'display notification "Git repository initialized" with title "SaneClick"'
            """,
            icon: "arrow.triangle.branch",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Initialize git repo with README and .gitignore"
        ),
        LibraryScript(
            name: "Open in VS Code",
            type: .bash,
            content: "code -- \"$@\"",
            icon: "chevron.left.forwardslash.chevron.right",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .developer,
            description: "Open in Visual Studio Code"
        ),
        LibraryScript(
            name: "Open in Cursor",
            type: .bash,
            content: "cursor -- \"$@\"",
            icon: "cursorarrow.rays",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .developer,
            description: "Open in Cursor editor"
        ),
        LibraryScript(
            name: "Open in Xcode",
            type: .bash,
            content: "open -a Xcode -- \"$@\"",
            icon: "hammer",
            appliesTo: .allItems,
            fileExtensions: ["swift", "xcodeproj", "xcworkspace", "playground"],
            category: .developer,
            description: "Open in Xcode"
        ),
        LibraryScript(
            name: "Run npm install",
            type: .bash,
            content: """
            (cd "$1" && npm install)
            osascript -e 'display notification "npm install complete" with title "SaneClick"'
            """,
            icon: "shippingbox",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Run npm install in folder"
        ),
        LibraryScript(
            name: "Format JSON",
            type: .bash,
            content: """
            for f in "$@"; do
                TEMP=$(mktemp)
                jq '.' -- "$f" > "$TEMP" && mv -f -- "$TEMP" "$f"
            done
            osascript -e 'display notification "JSON formatted" with title "SaneClick"'
            """,
            icon: "curlybraces",
            appliesTo: .filesOnly,
            fileExtensions: ["json"],
            category: .developer,
            description: "Pretty-print JSON file"
        ),
        LibraryScript(
            name: "Minify JSON",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                jq -c '.' "$f" > "${BASENAME}.min.json"
            done
            osascript -e 'display notification "JSON minified" with title "SaneClick"'
            """,
            icon: "arrow.down.right.and.arrow.up.left",
            appliesTo: .filesOnly,
            fileExtensions: ["json"],
            category: .developer,
            description: "Minify JSON to .min.json"
        ),
        LibraryScript(
            name: "Generate UUID",
            type: .bash,
            content: """
            UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
            echo -n "$UUID" | pbcopy
            osascript - "$UUID" <<'APPLESCRIPT'
            on run argv
                display notification (item 1 of argv) with title "UUID Copied"
            end run
            APPLESCRIPT
            """,
            icon: "number",
            appliesTo: .container,
            fileExtensions: [],
            category: .developer,
            description: "Generate and copy a new UUID"
        ),
        LibraryScript(
            name: "Base64 Encode",
            type: .bash,
            content: """
            base64 -i "$1" | tr -d '\\n' | pbcopy
            osascript -e 'display notification "Base64 copied to clipboard" with title "SaneClick"'
            """,
            icon: "doc.text",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Encode file to base64 and copy"
        ),
        LibraryScript(
            name: "Count Lines of Code",
            type: .bash,
            content: """
            NAME=$(basename -- "$1")
            COUNT=$(find "$1" -type f \\( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" \\) -print0 | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}')
            osascript - "$COUNT" "$NAME" <<'APPLESCRIPT'
            on run argv
                set lineCount to item 1 of argv
                set folderName to item 2 of argv
                display dialog ("Lines of code: " & lineCount) with title folderName buttons {"OK"} default button "OK"
            end run
            APPLESCRIPT
            """,
            icon: "number.square",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Count lines in source files"
        ),
        LibraryScript(
            name: "Create .gitignore",
            type: .bash,
            content: "cat > \"$1/.gitignore\" << 'EOF'\n# macOS\n.DS_Store\n.AppleDouble\n.LSOverride\n\n# Node\nnode_modules/\nnpm-debug.log*\n\n# Python\n__pycache__/\n*.py[cod]\n.env\nvenv/\n\n# Swift\n.build/\nDerivedData/\n*.xcuserstate\n\n# IDE\n.idea/\n.vscode/\n*.swp\nEOF\nosascript -e 'display notification \".gitignore created\" with title \"SaneClick\"'",
            icon: "doc.badge.gearshape",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Create comprehensive .gitignore"
        ),
        LibraryScript(
            name: "Start Python Server",
            type: .bash,
            content: """
            (cd "$1" && python3 -m http.server 8000) &
            sleep 1 && open "http://localhost:8000"
            """,
            icon: "network",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .developer,
            description: "Start local HTTP server on port 8000"
        )
    ]

    // MARK: - All Scripts

    static var allScripts: [LibraryScript] {
        universalScripts + developerScripts + designerScripts + powerUserScripts + organizationScripts
    }

    static var availableCategories: [ScriptCategory] {
        #if APP_STORE
            ScriptCategory.allCases.filter { !availableScripts(for: $0).isEmpty }
        #else
            ScriptCategory.allCases
        #endif
    }

    static var availableAllScripts: [LibraryScript] {
        #if APP_STORE
            allScripts.filter { AppStoreNativeAction(rawValue: $0.name) != nil }
        #else
            allScripts
        #endif
    }

    /// Get scripts for a specific category
    static func scripts(for category: ScriptCategory) -> [LibraryScript] {
        switch category {
        case .universal: universalScripts
        case .developer: developerScripts
        case .designer: designerScripts
        case .powerUser: powerUserScripts
        case .organization: organizationScripts
        }
    }

    static func availableScripts(for category: ScriptCategory) -> [LibraryScript] {
        #if APP_STORE
            scripts(for: category).filter { AppStoreNativeAction(rawValue: $0.name) != nil }
        #else
            scripts(for: category)
        #endif
    }

    static func libraryScript(named name: String) -> LibraryScript? {
        allScripts.first { $0.name == name }
    }
}
