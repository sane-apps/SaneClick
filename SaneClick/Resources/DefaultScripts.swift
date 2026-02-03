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
            description: String
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
                maxSelection: maxSelection
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
            case .universal: return "star.fill"
            case .organization: return "folder.fill"
            case .designer: return "photo.on.rectangle.angled"
            case .developer: return "chevron.left.forwardslash.chevron.right"
            case .powerUser: return "wrench.and.screwdriver.fill"
            }
        }

        var description: String {
            switch self {
            case .universal: return "Everyday actions everyone needs"
            case .organization: return "Sort, rename, and manage files"
            case .designer: return "Resize, convert, and edit images"
            case .developer: return "Tools for writing code"
            case .powerUser: return "Compression, hashing, system tools"
            }
        }

        /// Semantic color name for SwiftUI
        /// Meanings: blue=essential, green=safe, pink=creative, purple=technical, orange=warning
        var colorName: String {
            switch self {
            case .universal: return "blue"
            case .organization: return "green"
            case .designer: return "pink"
            case .developer: return "purple"
            case .powerUser: return "orange"
            }
        }
    }

    private static let imageExtensions = [
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
            description: "Clean up hidden Mac system files in folder"
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

    // MARK: - Designer Scripts

    static let designerScripts: [LibraryScript] = [
        LibraryScript(
            name: "Convert to PNG",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                sips -s format png -- "$f" --out "${BASENAME}.png"
            done
            osascript -e 'display notification "Converted to PNG" with title "SaneClick"'
            """,
            icon: "photo",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Convert image to PNG format"
        ),
        LibraryScript(
            name: "Convert to JPEG",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                sips -s format jpeg -s formatOptions 85 -- "$f" --out "${BASENAME}.jpg"
            done
            osascript -e 'display notification "Converted to JPEG" with title "SaneClick"'
            """,
            icon: "photo.fill",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Convert image to JPEG (85% quality)"
        ),
        LibraryScript(
            name: "HEIC to JPEG",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                sips -s format jpeg -- "$f" --out "${BASENAME}.jpg"
            done
            osascript -e 'display notification "HEIC converted to JPEG" with title "SaneClick"'
            """,
            icon: "iphone",
            appliesTo: .filesOnly,
            fileExtensions: ["heic"],
            category: .designer,
            description: "Convert iPhone HEIC photos to JPEG"
        ),
        LibraryScript(
            name: "Resize 50%",
            type: .bash,
            content: """
            for f in "$@"; do
                W=$(sips -g pixelWidth -- "$f" | awk '/pixelWidth/{print $2}')
                NEW_W=$((W / 2))
                sips --resampleWidth $NEW_W -- "$f"
            done
            osascript -e 'display notification "Images resized to 50%" with title "SaneClick"'
            """,
            icon: "arrow.down.right.and.arrow.up.left",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Resize image to half size"
        ),
        LibraryScript(
            name: "Resize to 1920px",
            type: .bash,
            content: """
            for f in "$@"; do
                sips --resampleWidth 1920 -- "$f"
            done
            osascript -e 'display notification "Images resized to 1920px width" with title "SaneClick"'
            """,
            icon: "rectangle.expand.vertical",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Resize image width to 1920px (Full HD)"
        ),
        LibraryScript(
            name: "Create Thumbnail (256px)",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                EXT="${f##*.}"
                sips -Z 256 -- "$f" --out "${BASENAME}_thumb.${EXT}"
            done
            osascript -e 'display notification "Thumbnails created" with title "SaneClick"'
            """,
            icon: "photo.on.rectangle",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Create 256px thumbnail version"
        ),
        LibraryScript(
            name: "Remove Photo Info",
            type: .bash,
            content: """
            for f in "$@"; do
                # Create clean copy by re-encoding (strips EXIF)
                EXT="${f##*.}"
                TEMP=$(mktemp).$EXT
                sips -s format ${EXT,,} -- "$f" --out "$TEMP" 2>/dev/null && mv -f -- "$TEMP" "$f"
            done
            osascript -e 'display notification "Photo info removed" with title "SaneClick"'
            """,
            icon: "eye.slash",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Remove location and camera info from photos"
        ),
        LibraryScript(
            name: "Get Image Dimensions",
            type: .bash,
            content: """
            INFO=""
            for f in "$@"; do
                SIZE=$(sips -g pixelWidth -g pixelHeight -- "$f" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')
                NAME=$(basename -- "$f")
                INFO="$INFO$NAME: $SIZE
            "
            done
            osascript - "$INFO" <<'APPLESCRIPT'
            on run argv
                set infoText to item 1 of argv
                display dialog infoText with title "Image Dimensions" buttons {"OK"} default button "OK"
            end run
            APPLESCRIPT
            """,
            icon: "ruler",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Show image width and height"
        ),
        LibraryScript(
            name: "Rotate 90° Clockwise",
            type: .bash,
            content: """
            for f in "$@"; do
                sips -r 90 -- "$f"
            done
            osascript -e 'display notification "Images rotated" with title "SaneClick"'
            """,
            icon: "rotate.right",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Rotate image 90 degrees clockwise"
        ),
        LibraryScript(
            name: "Create @2x Copy",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                EXT="${f##*.}"
                cp -n -- "$f" "${BASENAME}@2x.${EXT}"
                # Resize original to 50% (making it the @1x version)
                W=$(sips -g pixelWidth -- "$f" | awk '/pixelWidth/{print $2}')
                NEW_W=$((W / 2))
                sips --resampleWidth $NEW_W -- "$f"
            done
            osascript -e 'display notification "Created @2x versions" with title "SaneClick"'
            """,
            icon: "square.2.layers.3d",
            appliesTo: .filesOnly,
            fileExtensions: ["png"],
            category: .designer,
            description: "Create @2x retina version from current size"
        )
    ]

    // MARK: - Power User Scripts

    static let powerUserScripts: [LibraryScript] = [
        LibraryScript(
            name: "MD5 Hash",
            type: .bash,
            content: """
            HASH=$(md5 -q -- "$1")
            echo -n "$HASH" | pbcopy
            osascript - "$HASH" <<'APPLESCRIPT'
            on run argv
                display notification (item 1 of argv) with title "MD5 Copied"
            end run
            APPLESCRIPT
            """,
            icon: "number.circle",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .powerUser,
            description: "Get file's unique fingerprint (MD5)"
        ),
        LibraryScript(
            name: "SHA256 Hash",
            type: .bash,
            content: """
            HASH=$(shasum -a 256 -- "$1" | awk '{print $1}')
            echo -n "$HASH" | pbcopy
            osascript -e 'display notification "Hash copied" with title "SHA256"'
            """,
            icon: "lock.shield",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .powerUser,
            description: "Get file's unique fingerprint (SHA256)"
        ),
        LibraryScript(
            name: "Compress to ZIP",
            type: .bash,
            content: """
            for f in "$@"; do
                (
                    PARENT=$(dirname -- "$f")
                    NAME=$(basename -- "$f")
                    cd "$PARENT" || exit 1
                    zip -r -- "${NAME}.zip" "$NAME"
                )
            done
            osascript -e 'display notification "ZIP created" with title "SaneClick"'
            """,
            icon: "doc.zipper",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .powerUser,
            description: "Compress selected items to ZIP"
        ),
        LibraryScript(
            name: "Extract ZIP Here",
            type: .bash,
            content: """
            for f in "$@"; do
                unzip -n -- "$f" -d "$(dirname -- "$f")"
            done
            osascript -e 'display notification "Extracted" with title "SaneClick"'
            """,
            icon: "arrow.up.doc",
            appliesTo: .filesOnly,
            fileExtensions: ["zip"],
            category: .powerUser,
            description: "Extract ZIP to current folder"
        ),
        LibraryScript(
            name: "Create TAR.GZ",
            type: .bash,
            content: """
            for f in "$@"; do
                (
                    PARENT=$(dirname -- "$f")
                    NAME=$(basename -- "$f")
                    cd "$PARENT" || exit 1
                    tar -czvf "${NAME}.tar.gz" -- "$NAME"
                )
            done
            osascript -e 'display notification "TAR.GZ created" with title "SaneClick"'
            """,
            icon: "archivebox",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .powerUser,
            description: "Create .tar.gz archive (Linux-friendly)"
        ),
        LibraryScript(
            name: "Lock File",
            type: .bash,
            content: """
            for f in "$@"; do
                chflags uchg -- "$f"
            done
            osascript -e 'display notification "File(s) locked" with title "SaneClick"'
            """,
            icon: "lock",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .powerUser,
            description: "Protect file from being changed or deleted"
        ),
        LibraryScript(
            name: "Unlock File",
            type: .bash,
            content: """
            for f in "$@"; do
                chflags nouchg -- "$f"
            done
            osascript -e 'display notification "File(s) unlocked" with title "SaneClick"'
            """,
            icon: "lock.open",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .powerUser,
            description: "Remove protection from file"
        ),
        LibraryScript(
            name: "Secure Delete",
            type: .bash,
            content: """
            for f in "$@"; do
                # Only delete regular files, not symlinks
                if [ -f "$f" ] && [ ! -L "$f" ]; then
                    rm -P -- "$f"
                fi
            done
            osascript -e 'display notification "Securely deleted" with title "SaneClick"'
            """,
            icon: "trash.slash",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .powerUser,
            description: "Overwrite and delete file securely"
        ),
        LibraryScript(
            name: "View Raw Data",
            type: .bash,
            content: """
            HEX=$(xxd -- "$1" | head -50)
            echo "$HEX" | pbcopy
            PREVIEW=$(echo "$HEX" | head -10)
            NAME=$(basename -- "$1")
            osascript - "$PREVIEW" "$NAME" <<'APPLESCRIPT'
            on run argv
                set previewText to item 1 of argv
                set fileName to item 2 of argv
                display dialog ("First 50 lines copied to clipboard." & return & return & "Preview:" & return & previewText) with title ("Hex View: " & fileName) buttons {"OK"} default button "OK"
            end run
            APPLESCRIPT
            """,
            icon: "01.square",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .powerUser,
            description: "See raw data inside the file"
        ),
        LibraryScript(
            name: "Force Close Apps Using File",
            type: .bash,
            content: """
            PIDS=$(lsof -- "$1" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
            if [ -n "$PIDS" ]; then
                echo "$PIDS" | xargs kill -9
                osascript -e 'display notification "Processes killed" with title "SaneClick"'
            else
                osascript -e 'display notification "No processes using this file" with title "SaneClick"'
            fi
            """,
            icon: "xmark.circle",
            appliesTo: .filesOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .powerUser,
            description: "Close any apps that have this file open"
        )
    ]

    // MARK: - Organization Scripts

    static let organizationScripts: [LibraryScript] = [
        LibraryScript(
            name: "Move to Folder...",
            type: .applescript,
            content: """
            set destFolder to choose folder with prompt "Move selected items to:"
            repeat with f in argv
                set posixPath to POSIX file (f as text)
                tell application "Finder"
                    move posixPath to destFolder
                end tell
            end repeat
            """,
            icon: "folder.badge.plus",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .organization,
            description: "Move selected items to a chosen folder"
        ),
        LibraryScript(
            name: "Create Folder from Selection",
            type: .bash,
            content: """
            DIR=$(dirname -- "$1")
            FOLDER_NAME="New Folder $(date +%Y%m%d)"
            mkdir -p -- "$DIR/$FOLDER_NAME"
            for f in "$@"; do
                mv -n -- "$f" "$DIR/$FOLDER_NAME/"
            done
            osascript -e 'display notification "Items moved to new folder" with title "SaneClick"'
            """,
            icon: "folder.fill.badge.plus",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .organization,
            description: "Create folder and move selected items into it"
        ),
        LibraryScript(
            name: "Flatten Folder",
            type: .bash,
            content: """
            (
                cd "$1" || exit 1
                find . -mindepth 2 -type f -exec mv -n -- {} . \\;
                find . -type d -empty -delete
            )
            osascript -e 'display notification "Folder flattened" with title "SaneClick"'
            """,
            icon: "arrow.up.to.line",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .organization,
            description: "Move all nested files to root folder"
        ),
        LibraryScript(
            name: "Organize by Extension",
            type: .bash,
            content: """
            (
                cd "$1" || exit 1
                for f in *.*; do
                    if [ -f "$f" ] && [ ! -L "$f" ]; then
                        EXT="${f##*.}"
                        mkdir -p -- "$EXT"
                        mv -n -- "$f" "$EXT/"
                    fi
                done
            )
            osascript -e 'display notification "Files organized by extension" with title "SaneClick"'
            """,
            icon: "folder.badge.gearshape",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .organization,
            description: "Sort files into folders by extension"
        ),
        LibraryScript(
            name: "Organize by Date",
            type: .bash,
            content: """
            (
                cd "$1" || exit 1
                for f in *; do
                    if [ -f "$f" ] && [ ! -L "$f" ]; then
                        DATE=$(stat -f "%Sm" -t "%Y-%m" -- "$f")
                        mkdir -p -- "$DATE"
                        mv -n -- "$f" "$DATE/"
                    fi
                done
            )
            osascript -e 'display notification "Files organized by date" with title "SaneClick"'
            """,
            icon: "calendar",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            maxSelection: 1,
            category: .organization,
            description: "Sort files into YYYY-MM folders"
        ),
        LibraryScript(
            name: "Rename with Sequence",
            type: .bash,
            content: """
            COUNT=1
            for f in "$@"; do
                if [ -f "$f" ] && [ ! -L "$f" ]; then
                    DIR=$(dirname -- "$f")
                    EXT="${f##*.}"
                    NEWNAME=$(printf "%03d.%s" $COUNT "$EXT")
                    mv -n -- "$f" "$DIR/$NEWNAME"
                    COUNT=$((COUNT + 1))
                fi
            done
            osascript -e 'display notification "Files renamed" with title "SaneClick"'
            """,
            icon: "textformat.123",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .organization,
            description: "Rename files as 001, 002, 003..."
        ),
        LibraryScript(
            name: "Lowercase Filenames",
            type: .bash,
            content: """
            for f in "$@"; do
                if [ -e "$f" ] && [ ! -L "$f" ]; then
                    DIR=$(dirname -- "$f")
                    NAME=$(basename -- "$f")
                    LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
                    if [ "$NAME" != "$LOWER" ]; then
                        mv -n -- "$f" "$DIR/$LOWER"
                    fi
                fi
            done
            osascript -e 'display notification "Filenames lowercased" with title "SaneClick"'
            """,
            icon: "textformat.abc",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .organization,
            description: "Convert filenames to lowercase"
        ),
        LibraryScript(
            name: "Replace Spaces with Underscores",
            type: .bash,
            content: """
            for f in "$@"; do
                DIR=$(dirname -- "$f")
                NAME=$(basename -- "$f")
                NEWNAME=$(echo "$NAME" | tr ' ' '_')
                if [ "$NAME" != "$NEWNAME" ]; then
                    mv -n -- "$f" "$DIR/$NEWNAME"
                fi
            done
            osascript -e 'display notification "Spaces replaced" with title "SaneClick"'
            """,
            icon: "underscore",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .organization,
            description: "Replace spaces with underscores in names"
        )
    ]

    // MARK: - All Scripts

    static var allScripts: [LibraryScript] {
        universalScripts + developerScripts + designerScripts + powerUserScripts + organizationScripts
    }

    /// Get scripts for a specific category
    static func scripts(for category: ScriptCategory) -> [LibraryScript] {
        switch category {
        case .universal: return universalScripts
        case .developer: return developerScripts
        case .designer: return designerScripts
        case .powerUser: return powerUserScripts
        case .organization: return organizationScripts
        }
    }
}
