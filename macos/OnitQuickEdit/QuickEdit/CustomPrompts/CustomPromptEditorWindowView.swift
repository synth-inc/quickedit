//
//  CustomPromptEditorWindowView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import KeyboardShortcuts
import SwiftUI

/// Standalone window view for creating or editing a custom prompt (used in QuickEdit)
struct CustomPromptEditorWindowView: View {
    // MARK: - Properties

    let existingPrompt: CustomPrompt?

    // MARK: - Observed Objects

    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - State

    @State private var name: String
    @State private var promptText: String
    @State private var selectedIcon: String
    @State private var selectedApps: [String]
    @State private var showIconPicker: Bool = false

    // MARK: - Initialization

    init(existingPrompt: CustomPrompt?) {
        self.existingPrompt = existingPrompt

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
        isEditing ? String.localized("Edit Prompt", table: "QuickEdit") : String.localized("New Prompt", table: "QuickEdit")
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

            // Buttons
            buttonBar
        }
        .frame(width: 450, height: 520)
        .background(Color.S_7)
        .sheet(isPresented: $showIconPicker) {
            SFSymbolPickerView(selectedIcon: $selectedIcon)
        }
        .id(localization.currentLanguage)
    }

    // MARK: - Components

    private var titleBar: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.S_7)
    }

    private var buttonBar: some View {
        HStack {
            Button(String.localized("Cancel", table: "QuickEdit")) {
                closeWindow()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.T_8)
            .cornerRadius(6)

            Spacer()

            Button(action: savePrompt) {
                Text(isEditing ? String.localized("Save Changes", table: "QuickEdit") : String.localized("Create Prompt", table: "QuickEdit"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saveButtonDisabled)
        }
        .padding()
        .background(Color.S_7)
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

        Task {
            if isEditing {
                try? await CustomPromptManager.shared.updatePrompt(prompt)
            } else {
                try? await CustomPromptManager.shared.createPrompt(prompt)
            }
            await KeyboardShortcutsManager.refreshCustomPromptShortcuts()
        }

        closeWindow()
    }

    private func closeWindow() {
        CustomPromptEditorWindowManager.shared.closeWindow()
    }
}
