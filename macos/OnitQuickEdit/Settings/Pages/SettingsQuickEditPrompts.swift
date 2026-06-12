//
//  SettingsQuickEditPrompts.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct SettingsQuickEditPrompts: View {
    // MARK: - Defaults

    @Default(.quickEditConfig) private var config
    @Default(.quickEditShowHistoryWithoutTyping) private var showHistoryWithoutTyping

    // MARK: - State Objects

    @StateObject private var promptManager = CustomPromptManager.shared

    // MARK: - States

    @State private var showAddPrompt: Bool = false
    @State private var editingPrompt: CustomPrompt? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var promptToDelete: CustomPrompt? = nil
    @State private var draggedPrompt: CustomPrompt? = nil

    // MARK: - Computed Properties

    private var sortedPrompts: [CustomPrompt] {
        promptManager.customPrompts.sorted(by: { $0.order < $1.order })
    }

    // MARK: - Body

    var body: some View {
        Group {
            // Prompt History toggle
            SettingsPageSection {
                SettingsPageSubsection(
                    header: .init(
                        title: String.localized("Show Prompt History Without Typing", table: "Settings"),
                        subtitle: String.localized("When enabled, your recent prompts will appear immediately when QuickEdit opens. When disabled, you need to type at least one character before suggestions appear.", table: "Settings")
                    ),
                    isOn: $showHistoryWithoutTyping
                )
            }

            SettingsPageSection {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsPageSubsection(
                        header: .init(
                            title: String.localized("Show in QuickEdit", table: "Settings"),
                            subtitle: String.localized("These options will appear when hovering the hint \"Improve\" button.", table: "Settings")
                        ),
                        isOn: $config.showCustomPrompts
                    )

                    DividerHorizontal()

                    // Prompts list
                    if promptManager.customPrompts.isEmpty {
                        Text(String.localized("No custom prompts yet", table: "Settings"))
                            .styleText(size: 13, weight: .regular, color: Color.S_2)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(sortedPrompts) { prompt in
                                CustomPromptRow(
                                    prompt: prompt,
                                    onEdit: {
                                        guard !prompt.isSystemManaged else { return }
                                        editingPrompt = prompt
                                    },
                                    onDelete: {
                                        guard !prompt.isSystemManaged else { return }
                                        promptToDelete = prompt
                                        showDeleteConfirmation = true
                                    },
                                    onToggle: { isEnabled in
                                        Task {
                                            var updatedPrompt = prompt
                                            updatedPrompt.isEnabled = isEnabled
                                            try? await promptManager.updatePrompt(updatedPrompt)
                                        }
                                    },
                                    onDragStarted: {
                                        draggedPrompt = prompt
                                    },
                                    onDrop: { droppedPrompt in
                                        Task {
                                            await movePrompt(droppedPrompt, to: prompt)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Add button
                    SimpleButton(
                        text: String.localized("Add custom prompt...", table: "Settings"),
                        action: { showAddPrompt = true },
                        background: Color.S_3
                    )
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showAddPrompt) {
            CustomPromptFormView(existingPrompt: nil) { newPrompt in
                Task {
                    try? await promptManager.createPrompt(newPrompt)
                    await KeyboardShortcutsManager.refreshCustomPromptShortcuts()
                }
            }
        }
        .sheet(item: $editingPrompt) { prompt in
            CustomPromptFormView(existingPrompt: prompt) { updatedPrompt in
                Task {
                    try? await promptManager.updatePrompt(updatedPrompt)
                    await KeyboardShortcutsManager.refreshCustomPromptShortcuts()
                }
            }
        }
        .alert(String.localized("Delete Prompt", table: "Settings"), isPresented: $showDeleteConfirmation) {
            Button(String.localized("Cancel", table: "Settings"), role: .cancel) {
                promptToDelete = nil
            }
            Button(String.localized("Delete", table: "Settings"), role: .destructive) {
                if let prompt = promptToDelete,
                   !prompt.isSystemManaged
                {
                    Task {
                        try? await promptManager.deletePrompt(id: prompt.id)
                        await KeyboardShortcutsManager.refreshCustomPromptShortcuts()
                    }
                }
                promptToDelete = nil
            }
        } message: {
            Text(String(format: String.localized("Are you sure you want to delete \"%@\"? This action cannot be undone.", table: "Settings"), promptToDelete?.name ?? String.localized("this prompt", table: "Settings")))
        }
    }

    // MARK: - Private Functions

    /// Move the dragged prompt to the position of the target prompt
    private func movePrompt(_ draggedPrompt: CustomPrompt, to targetPrompt: CustomPrompt) async {
        var prompts = sortedPrompts

        guard let sourceIndex = prompts.firstIndex(where: { $0.id == draggedPrompt.id }),
              let destinationIndex = prompts.firstIndex(where: { $0.id == targetPrompt.id }),
              sourceIndex != destinationIndex else {
            return
        }

        // Remove from source and insert at destination
        let moved = prompts.remove(at: sourceIndex)
        prompts.insert(moved, at: destinationIndex)

        // Update order for all prompts
        try? await promptManager.reorderPrompts(prompts.enumerated().map { index, prompt in
            var updatedPrompt = prompt
            updatedPrompt.order = index
            return updatedPrompt
        })
    }
}
