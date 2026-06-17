//
//  QuickEditChatToolbar.swift
//  Onit
//
//  Created by Loyd Kim on 11/24/25.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct QuickEditChatToolbar: View {
    // MARK: - Properties

    @ObservedObject var state: QuickEditState
    @ObservedObject var selectionService = QuickEditSelectionService.shared
    @ObservedObject var diffService = QuickEditDiffService.shared
    @ObservedObject private var localization = LocalizationManager.shared
    let shouldShow: Bool

    // MARK: - States

    @State private var showModelPicker: Bool = false
    @State private var diffButtonIsHovered: Bool = false

    @Default(.quickEditMode) var quickEditMode
    @Default(.quickEditLocalModel) var quickEditLocalModel
    @Default(.quickEditRemoteModel) var quickEditRemoteModel

    // MARK: - Private Variables

    private var generatedPromptHasError: Bool {
        return state.error != nil
    }

    private var isGenerating: Bool {
        return state.generationState == .starting ||
               state.generationState == .generating ||
               state.generationState == .streaming
    }

    private var toolbarDisabled: Bool {
        return isGenerating || state.generationState == .notStarted
    }

    private var currentModelName: String {
        switch quickEditMode {
        case .local:
            return quickEditLocalModel ?? String.localized("Local", table: "QuickEdit")
        case .remote:
            return quickEditRemoteModel?.displayName ?? String.localized("Remote", table: "QuickEdit")
        }
    }

    private var hasGlobalHistory: Bool {
        selectionService.globalHistory.count > 1
    }

    private var globalHistoryPosition: (current: Int, total: Int) {
        selectionService.globalHistoryPosition
    }

    // MARK: - Body

    var body: some View {
        if shouldShow && !self.isGenerating {
            HStack(alignment: .center, spacing: 8) {
                insertButton

                Spacer()

                HStack(alignment: .center, spacing: 6) {
                    // Global history navigation (if multiple snapshots)
                    if hasGlobalHistory {
                        globalHistoryNavigation
                    }

                    #if DEBUG || ONIT_BETA
                    modelPickerButton
                    #endif
                    // Diff view only available in Improve mode
                    if state.mode == .improve {
                        diffToggleButton
                    }
                    copyButton
                    retryButton
                }
            }
            .id(localization.currentLanguage)
        }
    }

    // MARK: - Child Components

    @ViewBuilder
    private var insertButton: some View {
        if state.isEditableElement {
            let isDisabled = toolbarDisabled || generatedPromptHasError
            
            TextButton(
                text: String.localized("Insert", table: "QuickEdit"),
                colorConfig: .init(
                    background: Color.T_7
                ),
                sizeConfig: .init(
                    text: 12,
                    horizontalPadding: 8,
                    height: 28,
                    cornerRadius: 7
                ),
                alignmentConfig: .init(
                    gap: 4
                ),
                statusConfig: .init(
                    disabled: isDisabled
                )
            ) {
                Text(KeyboardShortcuts.Name.quickEditInsert.shortcutText)
                    .styleText(
                        size: 10,
                        weight: .regular,
                        color: Color.T_2
                    )
            } action: {
                guard !isDisabled else { return }
                Task {
                    await QuickEditManager.shared.insertResponse()
                }
            }
        }
    }

    @ViewBuilder
    private var diffToggleButton: some View {
        let isDisabled = toolbarDisabled || generatedPromptHasError || state.aiResponse.isEmpty
        let isActive = state.isDiffViewEnabled

        Button(action: {
            guard !isDisabled else { return }
            toggleDiffView()
        }) {
            Image(.charmDiff)
                .resizable()
                .renderingMode(.template)
                .frame(width: 14, height: 14)
                .foregroundColor(
                    isDisabled ? Color.S_0.opacity(0.5) : Color.S_0
                )
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(diffButtonIsHovered ? Color.T_8 : (isActive ? Color.T_8 : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            diffButtonIsHovered = hovering
        }
        .allowsHitTesting(!isDisabled)
    }

    private func toggleDiffView() {
        if state.isDiffViewEnabled {
            state.isDiffViewEnabled = false
            diffService.reset()
        } else {
            if let originalText = state.selectedText {
                diffService.computeDiff(original: originalText, response: state.aiResponse)
                state.isDiffViewEnabled = true
                state.isDiffNotificationDismissed = false
            }
        }
    }

    @ViewBuilder
    private var copyButton: some View {
        let isDisabled = toolbarDisabled || generatedPromptHasError || state.aiResponse.isEmpty
        CopyButton(text: state.aiResponse, stripMarkdown: true)
            .opacity(isDisabled ? 0.5 : 1)
            .allowsHitTesting(!isDisabled)
    }

    private var modelPickerButton: some View {
        TextButton(
            type: .clear,
            text: currentModelName,
            sizeConfig: .init(
                text: 13,
                horizontalPadding: 4,
                height: ToolbarButtonStyle.height,
                cornerRadius: 4
            ),
            statusConfig: .init(
                disabled: toolbarDisabled
            )
        ) {
            Image(.smallChevDown)
                .addIconStyles(
                    foregroundColor: toolbarDisabled ? Color.S_1.opacity(0.5) : (showModelPicker ? Color.S_0 : Color.S_1),
                    iconSize: 18
                )
                .addAnimation(dependency: showModelPicker)
                .rotationEffect(.degrees(showModelPicker ? 180 : 0))
        } action: {
            guard !toolbarDisabled else { return }
            showModelPicker.toggle()
        }
        .tooltip(prompt: String.localized("Change model", table: "QuickEdit"))
        .allowsHitTesting(!toolbarDisabled)
        .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
            QuickEditModelSelectionView(
                open: $showModelPicker,
                source: "QuickEdit"
            )
        }
    }

    private var retryButton: some View {
        IconButton(
            icon: .arrowsSpin,
            inactiveColor: toolbarDisabled ? Color.S_0.opacity(0.5) : Color.S_0
        ) {
            guard !toolbarDisabled else { return }
            let instruction = state.mode == .improve
                ? QuickEditManager.shared.improvePrompt
                : state.userInstruction
            QuickEditManager.shared.sendInstructionWithPaywallCheck(instruction)
        }
        .allowsHitTesting(!toolbarDisabled)
    }

    // MARK: - Global History Navigation

    private var globalHistoryNavigation: some View {
        let canGoBack = selectionService.canNavigateGlobalBack && !toolbarDisabled
        let canGoForward = selectionService.canNavigateGlobalForward && !toolbarDisabled

        return HStack(alignment: .center, spacing: 2) {
            // Previous snapshot button
            Button(action: {
                guard !toolbarDisabled else { return }
                if selectionService.navigateGlobalBack() {
                    state.aiResponse = selectionService.fullText
                    self.updateHeaderForCurrentSnapshot()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(canGoBack ? Color.S_0 : Color.S_2)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            // Position indicator
            Text("\(globalHistoryPosition.current)/\(globalHistoryPosition.total)")
                .styleText(size: 12, weight: .medium, color: toolbarDisabled ? Color.S_0.opacity(0.5) : Color.S_0)
                .padding(.horizontal, 4)

            // Next snapshot button
            Button(action: {
                guard !toolbarDisabled else { return }
                if selectionService.navigateGlobalForward() {
                    state.aiResponse = selectionService.fullText
                    self.updateHeaderForCurrentSnapshot()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(canGoForward ? Color.S_0 : Color.S_2)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.S_0.opacity(toolbarDisabled ? 0.05 : 0.1))
        .cornerRadius(6)
    }

    // MARK: - Private Helpers

    private func updateHeaderForCurrentSnapshot() {
        guard let snapshot = selectionService.currentSnapshot else { return }

        state.headerConfig = .fromInstruction(snapshot.instruction)
    }

}
