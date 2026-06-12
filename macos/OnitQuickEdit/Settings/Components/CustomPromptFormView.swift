//
//  CustomPromptFormView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import KeyboardShortcuts
import SwiftUI

/// Form view for creating or editing a custom prompt (used in Settings as a sheet)
struct CustomPromptFormView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let existingPrompt: CustomPrompt?
    let onSave: (CustomPrompt) -> Void

    // MARK: - State

    @State private var name: String
    @State private var promptText: String
    @State private var selectedIcon: String
    @State private var selectedApps: [String]
    @State private var showIconPicker: Bool = false

    // MARK: - Initialization

    init(existingPrompt: CustomPrompt?, onSave: @escaping (CustomPrompt) -> Void) {
        self.existingPrompt = existingPrompt
        self.onSave = onSave

        _name = State(initialValue: existingPrompt?.name ?? "")
        _promptText = State(initialValue: existingPrompt?.prompt ?? "")
        _selectedIcon = State(initialValue: existingPrompt?.icon ?? "wand.and.sparkles.inverse")
        _selectedApps = State(initialValue: existingPrompt?.apps ?? [])
    }

    // MARK: - Computed Properties

    private var isEditing: Bool {
        existingPrompt != nil
    }

    private var title: String {
        isEditing ? String.localized("Edit Prompt", table: "Settings") : String.localized("New Prompt", table: "Settings")
    }

    private var saveButtonDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var promptId: UUID {
        existingPrompt?.id ?? UUID()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Content
            ScrollView {
                CustomPromptFormContent(
                    name: $name,
                    promptText: $promptText,
                    selectedIcon: $selectedIcon,
                    selectedApps: $selectedApps,
                    showIconPicker: $showIconPicker,
                    promptId: promptId
                )
                .padding(20)
            }

            // Save button
            saveButton
        }
        .frame(width: 450, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showIconPicker) {
            SFSymbolPickerView(selectedIcon: $selectedIcon)
        }
    }

    // MARK: - Components

    private var titleBar: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button(action: savePrompt) {
                Text(isEditing ? String.localized("Save Changes", table: "Settings") : String.localized("Create Prompt", table: "Settings"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saveButtonDisabled)
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Actions

    private func savePrompt() {
        let shortcut = KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name(promptId.uuidString))
        let shortcutData = CustomPromptManager.shared.encodeShortcut(shortcut)

        let prompt = CustomPrompt.fromFormData(
            existingPrompt: existingPrompt,
            name: name,
            promptText: promptText,
            icon: selectedIcon,
            apps: selectedApps,
            shortcutData: shortcutData
        )

        onSave(prompt)
        dismiss()
    }
}
