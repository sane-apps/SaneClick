import SwiftUI

struct ScriptEditorView: View {
    let existingScript: Script?
    let onSave: (Script) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var type: ScriptType
    @State private var content: String
    @State private var isEnabled: Bool
    @State private var icon: String
    @State private var appliesTo: AppliesTo
    @State private var fileExtensionsText: String
    @State private var extensionMatchMode: ExtensionMatchMode
    @State private var categoryId: UUID?
    @State private var showingIconPicker = false
    @State private var showingTestOutput = false
    @State private var testOutput: String = ""
    @State private var testError: String?
    @State private var isRunningTest = false

    @Environment(ScriptStore.self) private var scriptStore

    init(script: Script?, onSave: @escaping (Script) -> Void) {
        self.existingScript = script
        self.onSave = onSave

        _name = State(initialValue: script?.name ?? "")
        _type = State(initialValue: script?.type ?? .bash)
        _content = State(initialValue: script?.content ?? "")
        _isEnabled = State(initialValue: script?.isEnabled ?? true)
        _icon = State(initialValue: script?.icon ?? "terminal")
        _appliesTo = State(initialValue: script?.appliesTo ?? .allItems)
        _fileExtensionsText = State(initialValue: script?.fileExtensions.joined(separator: ", ") ?? "")
        _extensionMatchMode = State(initialValue: script?.extensionMatchMode ?? .any)
        _categoryId = State(initialValue: script?.categoryId)
    }

    var body: some View {
        Form {
            generalSection
            fileFilterSection
            scriptSection
            previewSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $icon)
        }
        .sheet(isPresented: $showingTestOutput) {
            TestOutputView(
                scriptName: name.isEmpty ? "Untitled Script" : name,
                output: testOutput,
                error: testError
            )
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            HStack {
                TextField("Name", text: $name, prompt: Text("Script name"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("scriptNameField")

                Button {
                    showingIconPicker = true
                } label: {
                    Image(systemName: icon)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("iconPickerButton")
            }

            Picker("Type", selection: $type) {
                ForEach(ScriptType.allCases, id: \.self) { scriptType in
                    Label(scriptType.rawValue, systemImage: scriptType.icon)
                        .tag(scriptType)
                }
            }
            .accessibilityIdentifier("scriptTypeSelector")

            Picker("Applies To", selection: $appliesTo) {
                ForEach(AppliesTo.allCases, id: \.self) { target in
                    Label(target.rawValue, systemImage: target.icon)
                        .tag(target)
                }
            }
            .accessibilityIdentifier("appliesToSelector")

            if !scriptStore.categories.isEmpty {
                Picker("Category", selection: $categoryId) {
                    Text("Uncategorized").tag(nil as UUID?)
                    ForEach(scriptStore.categories) { category in
                        Label(category.name, systemImage: category.icon)
                            .tag(category.id as UUID?)
                    }
                }
                .accessibilityIdentifier("categorySelector")
            }

            Toggle("Enabled", isOn: $isEnabled)
                .accessibilityIdentifier("enabledToggle")
        }
    }

    // MARK: - File Filter Section

    private var fileFilterSection: some View {
        Section("File Type Filter") {
            TextField("File Extensions", text: $fileExtensionsText, prompt: Text("jpg, png, pdf (leave empty for all)"))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("fileExtensionsField")

            if !fileExtensionsText.isEmpty {
                Picker("Match Mode", selection: $extensionMatchMode) {
                    ForEach(ExtensionMatchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .accessibilityIdentifier("extensionMatchModeSelector")
            }

            Text("Only show this script when selected files match the extensions above. Separate multiple extensions with commas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Script Section

    private var scriptSection: some View {
        Section("Script Content") {
            if type == .automator {
                HStack {
                    TextField("Workflow Path", text: $content, prompt: Text("Path to .workflow file"))
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        browseForWorkflow()
                    }
                }
            } else {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .accessibilityIdentifier("scriptContentEditor")

                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var helpText: String {
        switch type {
        case .bash:
            return "Selected file paths are passed as arguments ($1, $2, etc.) or $@ for all."
        case .applescript:
            return "File paths are passed as argv. Use 'item 1 of argv' etc."
        case .automator:
            return "File paths are passed via standard input."
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section("Preview") {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.teal)
                    .frame(width: 20)

                Text(name.isEmpty ? "Untitled Script" : name)

                Spacer()

                Text(type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if existingScript == nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("cancelButton")
            }
        }

        ToolbarItem(placement: .automatic) {
            Button {
                testScript()
            } label: {
                if isRunningTest {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Test", systemImage: "play.fill")
                }
            }
            .disabled(content.isEmpty || isRunningTest || type == .automator)
            .help(type == .automator ? "Testing is not available for Automator workflows" : "Test script with selected files")
            .accessibilityIdentifier("testScriptButton")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                save()
            }
            .disabled(name.isEmpty || content.isEmpty)
            .accessibilityIdentifier("saveButton")
        }
    }

    // MARK: - Actions

    private func save() {
        // Parse file extensions from comma-separated string
        let extensions = fileExtensionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        let script = Script(
            id: existingScript?.id ?? UUID(),
            name: name,
            type: type,
            content: content,
            isEnabled: isEnabled,
            icon: icon,
            appliesTo: appliesTo,
            fileExtensions: extensions,
            extensionMatchMode: extensionMatchMode,
            categoryId: categoryId
        )
        onSave(script)

        if existingScript == nil {
            dismiss()
        }
    }

    private func testScript() {
        // Open file picker to select test files
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files to test the script with"
        panel.prompt = "Test"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        isRunningTest = true
        testOutput = ""
        testError = nil

        let paths = panel.urls.map { $0.path }

        Task {
            do {
                let result = try await runTestScript(paths: paths)
                await MainActor.run {
                    testOutput = result
                    testError = nil
                    isRunningTest = false
                    showingTestOutput = true
                }
            } catch {
                await MainActor.run {
                    testOutput = ""
                    testError = error.localizedDescription
                    isRunningTest = false
                    showingTestOutput = true
                }
            }
        }
    }

    private func runTestScript(paths: [String]) async throws -> String {
        switch type {
        case .bash:
            return try await runBashTest(paths: paths)
        case .applescript:
            return try await runAppleScriptTest(paths: paths)
        case .automator:
            throw NSError(domain: "SaneScript", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Automator workflows cannot be tested from the editor"
            ])
        }
    }

    private func runBashTest(paths: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", content] + paths
        process.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(domain: "SaneScript", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: errorOutput.isEmpty ? "Script exited with code \(process.terminationStatus)" : errorOutput
            ])
        }

        return output.isEmpty ? "(No output)" : output
    }

    private func runAppleScriptTest(paths: [String]) async throws -> String {
        // Build AppleScript with paths as argv
        let wrappedScript = """
        on run argv
            \(content)
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", wrappedScript] + paths

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(domain: "SaneScript", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: errorOutput.isEmpty ? "AppleScript exited with code \(process.terminationStatus)" : errorOutput
            ])
        }

        return output.isEmpty ? "(No output)" : output
    }

    private func browseForWorkflow() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "workflow")!]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            content = url.path
        }
    }
}

// MARK: - Icon Picker

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    private let icons = [
        "terminal", "applescript", "gearshape.2",
        "doc", "folder", "doc.on.clipboard",
        "arrow.right.circle", "trash", "pencil",
        "magnifyingglass", "square.and.arrow.up", "square.and.arrow.down",
        "link", "photo", "film",
        "music.note", "archivebox", "tray"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Icon")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: 12) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                        dismiss()
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(selectedIcon == icon ? Color.teal.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 320)
    }
}

// MARK: - Test Output View

struct TestOutputView: View {
    @Environment(\.dismiss) private var dismiss
    let scriptName: String
    let output: String
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(error == nil ? .green : .red)
                    .font(.title2)

                Text(error == nil ? "Test Completed" : "Test Failed")
                    .font(.headline)

                Spacer()
            }

            Divider()

            if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(error)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .accessibilityIdentifier("closeTestOutputButton")
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }
}

#Preview {
    ScriptEditorView(script: nil) { _ in }
        .environment(ScriptStore.shared)
}
