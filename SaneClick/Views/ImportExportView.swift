import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    enum Mode: String, CaseIterable {
        case importScripts = "Import"
        case exportScripts = "Export"

        var title: String { rawValue }

        var icon: String {
            switch self {
            case .importScripts: return "square.and.arrow.down"
            case .exportScripts: return "square.and.arrow.up"
            }
        }
    }

    @Environment(ScriptStore.self) private var scriptStore
    @Environment(\.dismiss) private var dismiss
    @Binding var mode: Mode

    @State private var importMode: ScriptImportMode = .skipDuplicates
    @State private var statusMessage: StatusMessage?
    @State private var lastExportURL: URL?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 16) {
            header

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if let statusMessage {
                StatusBanner(message: statusMessage)
            }

            if mode == .importScripts {
                importSection
            } else {
                exportSection
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 540, height: 420)
        .background(Color.saneNavy.opacity(0.3))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.saneTeal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Import and Export")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Move your right-click actions between Macs")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)
            }

            Spacer()
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoCard(
                title: "Import scripts",
                subtitle: "Bring in actions from a JSON file",
                icon: "square.and.arrow.down"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("When an action already exists")
                    .font(.subheadline)
                    .foregroundStyle(Color.saneSilver)

                Picker("Import mode", selection: $importMode) {
                    ForEach(ScriptImportMode.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(importMode.detail)
                    .font(.caption)
                    .foregroundStyle(Color.saneSilver)
            }

            Button {
                importScripts()
            } label: {
                Label("Choose JSON File", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(.saneTeal)
            .disabled(isWorking)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoCard(
                title: "Export scripts",
                subtitle: "Save all actions to a JSON file",
                icon: "square.and.arrow.up"
            )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(scriptStore.scripts.count) actions")
                        .font(.headline)
                    Text("Includes enabled and disabled actions")
                        .font(.caption)
                        .foregroundStyle(Color.saneSilver)
                }

                Spacer()

                Button {
                    exportScripts()
                } label: {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.saneTeal)
                .disabled(isWorking)
            }

            if let exportURL = lastExportURL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([exportURL])
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.saneCarbon)
        }
    }

    private func infoCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.saneTeal)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.saneSilver)
            }

            Spacer()
        }
    }

    private func importScripts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a SaneClick scripts JSON file"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            let summary = try scriptStore.importScripts(from: url, mode: importMode)
            statusMessage = StatusMessage(
                kind: .success,
                text: importSummaryText(summary)
            )
        } catch {
            statusMessage = StatusMessage(
                kind: .error,
                text: "Import failed: \(error.localizedDescription)"
            )
        }
    }

    private func exportScripts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "SaneClick Scripts.json"
        panel.canCreateDirectories = true
        panel.message = "Export your SaneClick actions"
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            try scriptStore.exportScripts(to: url)
            lastExportURL = url
            statusMessage = StatusMessage(
                kind: .success,
                text: "Exported \(scriptStore.scripts.count) actions."
            )
        } catch {
            statusMessage = StatusMessage(
                kind: .error,
                text: "Export failed: \(error.localizedDescription)"
            )
        }
    }

    private func importSummaryText(_ summary: ScriptImportSummary) -> String {
        var parts: [String] = []
        if summary.added > 0 {
            parts.append("\(summary.added) \(pluralize(summary.added, "action")) added")
        }
        if summary.updated > 0 {
            parts.append("\(summary.updated) \(pluralize(summary.updated, "action")) updated")
        }
        if summary.skipped > 0 {
            parts.append("\(summary.skipped) \(pluralize(summary.skipped, "action")) skipped")
        }

        let base = parts.isEmpty ? "No actions imported." : parts.joined(separator: ", ") + "."

        if summary.categoriesAdded > 0 {
            return "\(base) \(summary.categoriesAdded) \(pluralize(summary.categoriesAdded, "category")) added."
        }

        return base
    }

    private func pluralize(_ count: Int, _ singular: String) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}

private struct StatusMessage {
    enum Kind {
        case success
        case error
        case warning
    }

    let kind: Kind
    let text: String
}

private struct StatusBanner: View {
    let message: StatusMessage

    private var backgroundColor: Color {
        switch message.kind {
        case .success: return Color.saneSuccess.opacity(0.15)
        case .error: return Color.saneError.opacity(0.15)
        case .warning: return Color.saneWarning.opacity(0.15)
        }
    }

    private var borderColor: Color {
        switch message.kind {
        case .success: return Color.saneSuccess
        case .error: return Color.saneError
        case .warning: return Color.saneWarning
        }
    }

    private var iconName: String {
        switch message.kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(borderColor)
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(Color.saneCloud)
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor.opacity(0.6), lineWidth: 1)
        }
    }
}

#Preview {
    ImportExportView(mode: .constant(.importScripts))
        .environment(ScriptStore.shared)
}
