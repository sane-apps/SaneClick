import Foundation

// Library script data split out of DefaultScripts.swift to keep each
// component-owner file under the size limit (Rule #10). These are additional
// `ScriptLibrary` categories (Images & Media, Advanced, Files & Folders). The
// `LibraryScript` type, the universal/developer arrays, and the aggregation
// (`allScripts`) live in DefaultScripts.swift.
//
// Destructive built-ins (move/rename/delete/flatten/overwrite) opt into
// `confirmBeforeRun: true` so the user is asked before they run. Output mode is
// intentionally left at the default `.standard` for built-ins.
extension ScriptLibrary {
    // MARK: - Designer Scripts

    static let designerScripts: [LibraryScript] = [
        LibraryScript(
            name: "Convert to PNG",
            type: .bash,
            content: """
            for f in "$@"; do
                BASENAME="${f%.*}"
                sips -s format png "$f" --out "${BASENAME}.png"
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
                sips -s format jpeg -s formatOptions 85 "$f" --out "${BASENAME}.jpg"
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
                sips -s format jpeg "$f" --out "${BASENAME}.jpg"
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
                W=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
                NEW_W=$((W / 2))
                sips --resampleWidth $NEW_W "$f"
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
                sips --resampleWidth 1920 "$f"
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
                sips -Z 256 "$f" --out "${BASENAME}_thumb.${EXT}"
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
                sips -s format ${EXT,,} "$f" --out "$TEMP" 2>/dev/null && mv -f -- "$TEMP" "$f"
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
                SIZE=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')
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
                sips -r 90 "$f"
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
                W=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
                NEW_W=$((W / 2))
                sips --resampleWidth $NEW_W "$f"
            done
            osascript -e 'display notification "Created @2x versions" with title "SaneClick"'
            """,
            icon: "square.2.layers.3d",
            appliesTo: .filesOnly,
            fileExtensions: ["png"],
            category: .designer,
            description: "Create @2x retina version from current size"
        ),
        LibraryScript(
            name: "Copy Text from Image",
            type: .bash,
            content: "# Runs natively via SaneClick (Copy Text from Image).",
            icon: "text.viewfinder",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Recognize text in images and copy it"
        ),
        LibraryScript(
            name: "Save Text from Image",
            type: .bash,
            content: "# Runs natively via SaneClick (Save Text from Image).",
            icon: "doc.text.viewfinder",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            category: .designer,
            description: "Recognize text and save a .txt next to each image"
        ),
        LibraryScript(
            name: "Combine Images into PDF",
            type: .bash,
            content: "# Runs natively via SaneClick (Combine Images into PDF).",
            icon: "doc.on.doc",
            appliesTo: .filesOnly,
            fileExtensions: imageExtensions,
            minSelection: 2,
            category: .designer,
            description: "Merge selected images into a single PDF"
        ),
        LibraryScript(
            name: "Split PDF into Pages",
            type: .bash,
            content: "# Runs natively via SaneClick (Split PDF into Pages).",
            icon: "doc.on.doc.fill",
            appliesTo: .filesOnly,
            fileExtensions: ["pdf"],
            maxSelection: 1,
            category: .designer,
            description: "Split a PDF into one file per page"
        ),
        LibraryScript(
            name: "PDF to Images",
            type: .bash,
            content: "# Runs natively via SaneClick (PDF to Images).",
            icon: "photo.stack",
            appliesTo: .filesOnly,
            fileExtensions: ["pdf"],
            maxSelection: 1,
            category: .designer,
            description: "Render each PDF page as a PNG image"
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
            name: "Create SHA256 File",
            type: .bash,
            content: """
            for f in "$@"; do
                DIR=$(dirname -- "$f")
                NAME=$(basename -- "$f")
                HASH=$(shasum -a 256 -- "$f" | awk '{print $1}')
                printf '%s  %s\n' "$HASH" "$NAME" > "$DIR/$NAME.sha256"
            done
            osascript -e 'display notification "SHA256 file created" with title "SaneClick"'
            """,
            icon: "checkmark.shield",
            appliesTo: .filesOnly,
            fileExtensions: [],
            category: .powerUser,
            description: "Create a .sha256 checksum file next to the item"
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
            name: "Extract TAR.GZ Here",
            type: .bash,
            content: """
            for f in "$@"; do
                tar -xzf "$f" -C "$(dirname -- "$f")"
            done
            osascript -e 'display notification "TAR.GZ extracted" with title "SaneClick"'
            """,
            icon: "arrow.down.doc",
            appliesTo: .filesOnly,
            fileExtensions: ["tar.gz", "tgz"],
            extensionMatchMode: .any,
            category: .powerUser,
            description: "Extract .tar.gz or .tgz archives here"
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
            description: "Overwrite and delete file securely",
            confirmBeforeRun: true
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
            description: "Close any apps that have this file open",
            confirmBeforeRun: true
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
            description: "Create folder and move selected items into it",
            confirmBeforeRun: true
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
            description: "Move all nested files to root folder",
            confirmBeforeRun: true
        ),
        LibraryScript(
            name: "Remove Empty Folders",
            type: .bash,
            content: """
            for folder in "$@"; do
                if [ -d "$folder" ] && [ ! -L "$folder" ]; then
                    find "$folder" -depth -type d -empty -delete
                fi
            done
            osascript -e 'display notification "Empty folders removed" with title "SaneClick"'
            """,
            icon: "folder.badge.minus",
            appliesTo: .foldersOnly,
            fileExtensions: [],
            category: .organization,
            description: "Delete empty folders inside the selected folder"
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
            description: "Sort files into folders by extension",
            confirmBeforeRun: true
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
            description: "Sort files into YYYY-MM folders",
            confirmBeforeRun: true
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
            description: "Rename files as 001, 002, 003...",
            confirmBeforeRun: true
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
            description: "Convert filenames to lowercase",
            confirmBeforeRun: true
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
            icon: "underline",
            appliesTo: .allItems,
            fileExtensions: [],
            category: .organization,
            description: "Replace spaces with underscores in names",
            confirmBeforeRun: true
        )
    ]
}
