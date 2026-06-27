//
//  QuickEditHintView.swift
//  Onit
//
//  Created by Loyd Kim on 11/20/25.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct QuickEditHintView: View {
    // MARK: - State

    @StateObject private var promptManager = CustomPromptManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Default(.quickEditConfig) private var config
    @State private var isHoveringButton: Bool = false
    @State private var isHoveringPromptList: Bool = false
    @State private var hideButtonTask: Task<Void, Never>?
    @State private var hidePromptListTask: Task<Void, Never>?

    private var showPromptList: Bool {
        isHoveringButton || isHoveringPromptList
    }

    // MARK: - Types

    private struct Action {
        let id: UUID
        let text: String
        let subtext: String?
        let isDefaultPrompt: Bool
        let callback: () -> Void

        init(
            id: UUID = UUID(),
            text: String,
            subtext: String? = nil,
            isDefaultPrompt: Bool = false,
            callback: @escaping () -> Void
        ) {
            self.id = id
            self.text = text
            self.subtext = subtext
            self.isDefaultPrompt = isDefaultPrompt
            self.callback = callback
        }
    }

    // MARK: - Computed Properties

    private var currentAppBundleID: String? {
        QuickEditManager.shared.state.currentAppBundleId
    }

    private var defaultPrompt: CustomPrompt? {
        guard config.showCustomPrompts else { return nil }
        return promptManager.getDefaultPrompt(forApp: currentAppBundleID)
    }

    private var actions: [Action] {
        var result: [Action] = []

        // Default prompt action (replaces "Improve")
        if let prompt = defaultPrompt {
            result.append(Action(
                id: prompt.id,
                text: prompt.localizedName,
                subtext: prompt.shortcutText,
                isDefaultPrompt: true
            ) { [self] in
                // Hide the prompt list if visible
                QuickEditPromptListWindowController.shared.hide()
                hideButtonTask?.cancel()
                hidePromptListTask?.cancel()
                isHoveringButton = false
                isHoveringPromptList = false

                AnalyticsManager.QuickEdit.hintClicked()
                QuickEditManager.shared.executeCustomPrompt(prompt)
            })
        } else {
            // Fallback to hardcoded Improve if no custom prompts
            result.append(Action(
                text: String.localized("Improve", table: "QuickEdit"),
                subtext: KeyboardShortcuts.Name.quickEditImprove.shortcutText,
                isDefaultPrompt: true
            ) {
                AnalyticsManager.QuickEdit.hintClicked()
                QuickEditManager.shared.improve()
            })
        }

        // Edit action (always present)
        result.append(Action(
            text: String.localized("Edit", table: "QuickEdit"),
            subtext: KeyboardShortcuts.Name.quickEditPrompt.shortcutText
        ) {
            AnalyticsManager.QuickEdit.hintClicked()
            QuickEditManager.shared.prompt()
        })

        return result
    }

    // MARK: - Body

    var body: some View {
        hintView
    }

    // MARK: - Child Components

    private var logo: some View {
        Image(.noodle)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: 12, height: 12)
            .foregroundStyle(Color.S_0)
            .padding(3)
            .frame(width: 18, height: 18)
    }

    private struct ActionButton: View {
        let action: QuickEditHintView.Action
        let onButtonHover: ((Bool) -> Void)?

        @State private var isHovered: Bool = false
        @State private var isPressed: Bool = false

        init(
            action: QuickEditHintView.Action,
            onButtonHover: ((Bool) -> Void)? = nil
        ) {
            self.action = action
            self.onButtonHover = onButtonHover
        }

        var body: some View {
            HStack(alignment: .center, spacing: 2) {
                Text(action.text)
                    .styleText(
                        size: 13,
                        weight: .regular
                    )

                if let subtext = action.subtext {
                    Text(subtext)
                        .styleText(
                            size: 11,
                            color: Color.S_0.opacity(0.6)
                        )
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .addButtonEffects(
                hoverBackground: Color.S_0.opacity(0.2),
                cornerRadius: 6,
                isHovered: $isHovered,
                isPressed: $isPressed
            ) {
                action.callback()
            }
            .onHover { hovering in
                onButtonHover?(hovering)
            }
        }
    }

    private var hintView: some View {
        HStack(alignment: .center, spacing: 6) {
            logo

            ForEach(actions, id: \.id) { action in
                if action.isDefaultPrompt && config.showCustomPrompts {
                    ActionButton(
                        action: action,
                        onButtonHover: { hovering in
                            handleButtonHover(hovering)
                        }
                    )
                } else {
                    ActionButton(action: action)
                }
            }
        }
        .padding(.leading, 5)
        .padding([.vertical, .trailing], 3)
        .fixedSize()
        .background(Color.S_10.opacity(0.4))
        .background(Backgrounds.BrushedGlass())
        .addBorder(cornerRadius: 9, stroke: Color.T_7)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: showPromptList) { _, shouldShow in
                        handlePromptListVisibility(shouldShow: shouldShow, geometry: geometry)
                    }
            }
        )
        .id(localization.currentLanguage)
    }

    // MARK: - Prompt List Window

    private func handlePromptListVisibility(shouldShow: Bool, geometry: GeometryProxy) {
        if shouldShow && config.showCustomPrompts {
            // Get the hint window frame from the controller
            if let hintFrame = QuickEditManager.shared.hintWindowController.currentFrame {
                showPromptListWindow(anchoredTo: hintFrame)
            }
        } else {
            QuickEditPromptListWindowController.shared.hide()
        }
    }

    private func showPromptListWindow(anchoredTo hintFrame: CGRect) {
        QuickEditPromptListWindowController.shared.show(
            anchoredTo: hintFrame,
            currentAppBundleID: currentAppBundleID,
            onPromptSelected: { prompt in
                hideButtonTask?.cancel()
                hidePromptListTask?.cancel()
                isHoveringButton = false
                isHoveringPromptList = false
                AnalyticsManager.QuickEdit.hintClicked()
                QuickEditManager.shared.executeCustomPrompt(prompt)
            },
            onEditPrompt: { prompt in
                guard !prompt.isSystemManaged else { return }
                hideButtonTask?.cancel()
                hidePromptListTask?.cancel()
                isHoveringButton = false
                isHoveringPromptList = false
                CustomPromptEditorWindowManager.shared.showWindow(prompt: prompt)
            },
            onDeletePrompt: { prompt in
                guard !prompt.isSystemManaged else { return }
                hideButtonTask?.cancel()
                hidePromptListTask?.cancel()
                isHoveringButton = false
                isHoveringPromptList = false
                showDeleteConfirmation(for: prompt)
            },
            onHover: { hovering in
                handlePromptListHover(hovering)
            }
        )
    }

    // MARK: - Hover Handlers

    private func handleButtonHover(_ hovering: Bool) {
        hideButtonTask?.cancel()
        if hovering {
            isHoveringButton = true
        } else {
            // Delay hiding to allow transition to prompt list
            hideButtonTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                if !Task.isCancelled {
                    isHoveringButton = false
                }
            }
        }
    }

    private func handlePromptListHover(_ hovering: Bool) {
        hidePromptListTask?.cancel()
        if hovering {
            isHoveringPromptList = true
        } else {
            // Delay hiding to allow transition back to button
            hidePromptListTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                if !Task.isCancelled {
                    isHoveringPromptList = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func showDeleteConfirmation(for prompt: CustomPrompt) {
        guard !prompt.isSystemManaged else { return }
        
        let alert = NSAlert()
        alert.messageText = String.localized("Delete Prompt", table: "QuickEdit")
        alert.informativeText = String.localized("Are you sure you want to delete \"%@\"? This action cannot be undone.", table: "QuickEdit", prompt.localizedName)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String.localized("Delete", table: "QuickEdit"))
        alert.addButton(withTitle: String.localized("Cancel", table: "QuickEdit"))

        // Style the Delete button as destructive
        if let deleteButton = alert.buttons.first {
            deleteButton.hasDestructiveAction = true
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                try? await promptManager.deletePrompt(id: prompt.id)
                await KeyboardShortcutsManager.refreshCustomPromptShortcuts()
            }
        }
    }
}
