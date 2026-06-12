//
//  SelectionHintView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import SwiftUI

/// The display mode of the selection hint
enum SelectionHintMode: Equatable {
    /// Default mode showing action buttons
    case actions
    /// AI-Edit mode showing text input
    case aiEdit
    /// Diff undo mode showing undo button
    case diffUndo
}

/// The context determining which buttons to show
enum SelectionHintContext: Equatable {
    /// Standard mode: Freeze | AI-Edit | Retry
    case standard
    /// Mode with frozen text selected: Freeze | Un-freeze | Un-freeze all
    case withFrozenSelection
}

/// View for the selection hint showing context-aware actions
struct SelectionHintView: View {

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Observed Objects

    @ObservedObject var viewModel: SelectionHintViewModel
    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.mode {
            case .actions:
                actionsView
            case .aiEdit:
                aiEditView
            case .diffUndo:
                diffUndoView
            }
        }
        .background {
            Color.S_10.opacity(0.65)
                .background(Backgrounds.BrushedGlass())
        }
        .cornerRadius(9)
        .addBorder(cornerRadius: 9, stroke: Color.T_7)
        .id(localization.currentLanguage)
    }

    // MARK: - Actions View

    private var actionsView: some View {
        HStack(alignment: .center, spacing: 4) {
            switch viewModel.context {
            case .standard:
                // Freeze | AI-Edit | Retry
                freezeButton
                aiEditButton
                retryButton

            case .withFrozenSelection:
                // Freeze | Un-freeze | Un-freeze all
                freezeButton
                unfreezeButton
                if viewModel.showUnfreezeAll {
                    unfreezeAllButton
                }
            }

            // Version pagination (if multiple versions and not in frozen mode)
            if let versionInfo = viewModel.versionInfo,
               viewModel.context != .withFrozenSelection {
                versionNavigation(current: versionInfo.current, total: versionInfo.total)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .fixedSize()
    }

    // MARK: - AI-Edit View

    private var aiEditView: some View {
        HStack(alignment: .center, spacing: 8) {
            AIEditTextField(
                text: $viewModel.aiEditText,
                placeholder: String.localized("Describe any changes...", table: "QuickEdit"),
                onSubmit: viewModel.onAIEditSubmit,
                onCancel: viewModel.onAIEditCancel
            )

            // Submit button
            Button(action: viewModel.onAIEditSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.aiEditText.isEmpty ? Color.S_2 : Color.blue400)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.aiEditText.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 250)
    }

    // MARK: - Diff Undo View

    private var diffUndoView: some View {
        HStack(alignment: .center, spacing: 4) {
            HintActionButton(
                icon: .arrowsSpin,
                text: "Undo change",
                action: viewModel.onDiffUndo
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .fixedSize()
        .onHover { isHovering in
            if !isHovering {
                viewModel.onDiffUndoHoverExit()
            }
        }
    }

    // MARK: - Buttons

    private var freezeButton: some View {
        HintActionButton(
            icon: .snowFlakes,
            text: String.localized("Freeze", table: "QuickEdit"),
            action: viewModel.onFreeze
        )
    }

    private var aiEditButton: some View {
        HintActionButton(
            icon: .magicEdit,
            text: String.localized("AI-Edit", table: "QuickEdit"),
            action: viewModel.onAIEditTap
        )
    }

    private var retryButton: some View {
        HintActionButton(
            icon: .arrowsSpin,
            text: String.localized("Retry", table: "QuickEdit"),
            action: viewModel.onRetry
        )
    }

    private var unfreezeButton: some View {
        HintActionButton(
            icon: .freezeCross,
            text: String.localized("Un-freeze", table: "QuickEdit"),
            action: viewModel.onUnfreeze
        )
    }

    private var unfreezeAllButton: some View {
        HintActionButton(
            icon: .freezeCross,
            text: String.localized("Un-freeze all", table: "QuickEdit"),
            action: viewModel.onUnfreezeAll
        )
    }

    // MARK: - Child Components

    private func versionNavigation(current: Int, total: Int) -> some View {
        HStack(alignment: .center, spacing: 2) {
            // Previous version button
            Button(action: viewModel.onPreviousVersion) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(current > 1 ? Color.S_0 : Color.S_2)
            }
            .buttonStyle(.plain)
            .disabled(current <= 1)

            // Version indicator
            Text("\(current)/\(total)")
                .styleText(size: 12, weight: .medium, color: Color.S_0)
                .padding(.horizontal, 4)

            // Next version button
            Button(action: viewModel.onNextVersion) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(current < total ? Color.S_0 : Color.S_2)
            }
            .buttonStyle(.plain)
            .disabled(current >= total)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - AI-Edit TextField

private struct AIEditTextField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    // Maximum visible lines before scrolling
    private let maxVisibleLines = 5
    private let lineHeight: CGFloat = 18

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(Color.S_0)
            .focused($isFocused)
            .onSubmit {
                if !text.isEmpty {
                    onSubmit()
                }
            }
            .frame(minWidth: 180)
        .onAppear {
            // Delay focus to ensure the view is fully rendered and window is key
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}
