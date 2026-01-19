import SwiftUI

struct ScriptCategoryEditorView: View {
    let existingScriptCategory: ScriptCategory?
    let onSave: (ScriptCategory) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var icon: String
    @State private var showingIconPicker = false

    init(category: ScriptCategory?, onSave: @escaping (ScriptCategory) -> Void) {
        self.existingScriptCategory = category
        self.onSave = onSave

        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? "folder")
    }

    var body: some View {
        Form {
            Section("ScriptCategory Details") {
                HStack {
                    TextField("Name", text: $name, prompt: Text("ScriptCategory name"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("categoryNameField")

                    Button {
                        showingIconPicker = true
                    } label: {
                        Image(systemName: icon)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("categoryIconButton")
                }
            }

            Section("Preview") {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(.teal)
                        .frame(width: 20)

                    Text(name.isEmpty ? "New ScriptCategory" : name)
                        .font(.headline)

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 300, minHeight: 200)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("cancelScriptCategoryButton")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.isEmpty)
                .accessibilityIdentifier("saveScriptCategoryButton")
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            ScriptCategoryIconPickerView(selectedIcon: $icon)
        }
    }

    private func save() {
        let category = ScriptCategory(
            id: existingScriptCategory?.id ?? UUID(),
            name: name,
            icon: icon
        )
        onSave(category)
        dismiss()
    }
}

// MARK: - Icon Picker

struct ScriptCategoryIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    private let icons = [
        "folder", "folder.fill", "tray", "tray.fill",
        "archivebox", "archivebox.fill", "shippingbox", "shippingbox.fill",
        "star", "star.fill", "bookmark", "bookmark.fill",
        "tag", "tag.fill", "heart", "heart.fill",
        "bolt", "bolt.fill", "gear", "gearshape",
        "wrench", "hammer", "screwdriver", "wrench.and.screwdriver",
        "paintbrush", "wand.and.stars", "sparkles", "square.grid.3x3",
        "doc", "doc.fill", "photo", "film",
        "terminal", "curlybraces", "chevron.left.forwardslash.chevron.right", "ladybug"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Icon")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 8), spacing: 12) {
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
        .frame(width: 420)
    }
}

#Preview {
    ScriptCategoryEditorView(category: nil) { _ in }
}
