//
//  QuickEditChat.swift
//  Onit
//
//  Created by Loyd Kim on 11/24/25.
//

import Defaults
import SwiftUI

struct QuickEditChat: View {
    // MARK: - Defaults

    @Default(.fontSize) private var fontSize
    @Default(.lineHeight) private var lineHeight

    // MARK: - Properties

    @ObservedObject var state: QuickEditState
    @ObservedObject var selectionService = QuickEditSelectionService.shared
    @ObservedObject var selectionCoordinator = QuickEditSelectionCoordinator.shared
    @ObservedObject var diffService = QuickEditDiffService.shared
    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - State

    @State private var regeneratingRects: [CGRect] = []
    @State private var textViewHeight: CGFloat = 20

    // MARK: - Private Variables

    private var promptTextFieldMinHeight: CGFloat {
        fontSize
    }

    /// Max height for the chat content area, calculated based on mode and notification visibility
    private var promptTextFieldMaxHeight: CGFloat {
        var baseHeight: CGFloat
        if state.mode == .improve {
            baseHeight = QuickEditConstants.maxWindowHeight - 119
        } else {
            baseHeight = QuickEditConstants.maxWindowHeight - 135
        }

        // Reserve space for diff notification if visible
        if state.isDiffNotificationVisible {
            baseHeight -= QuickEditState.diffNotificationHeight
        }

        return baseHeight
    }

    private var hasProminentHeaderConfig: Bool {
        guard let headerConfig = state.headerConfig else {
            return false
        }
        return headerConfig.isProminent
    }

    // MARK: - Computed Properties

    /// Binding for the text displayed in SelectableTextView
    /// When showing inline deletions, uses displayText; otherwise uses aiResponse
    private var displayedTextBinding: Binding<String> {
        Binding(
            get: {
                // When diff mode is enabled and showing inline deletions, use displayText
                if state.isDiffViewEnabled && diffService.showDeletedTextInDiff && !diffService.displayText.isEmpty {
                    return diffService.displayText
                }
                return state.aiResponse
            },
            set: { newValue in
                // Editing is disabled in diff mode, but handle writes to aiResponse
                state.aiResponse = newValue
            }
        )
    }

    private var isLightMode: Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }

    private var textColor: Color {
        isLightMode ? Color.black : Color.white
    }

    private var loadingText: String {
        state.mode == .improve ? String.localized("Improving...", table: "QuickEdit") : String.localized("Applying...", table: "QuickEdit")
    }

    // MARK: - Body

    var body: some View {
        let currentGenerationState = state.generationState

        return VStack(alignment: .leading, spacing: 0) {
            if state.isAuthWallActive {
                authWallContent
            } else if state.isPaywallActive {
                paywallContent(for: currentGenerationState)
            } else {
                normalContent(for: currentGenerationState)
            }
        }
        .id(localization.currentLanguage)
    }

    // MARK: - Auth Wall Content

    private var authWallContent: some View {
        QuickEditAuthWallView(
            originalText: state.selectedText ?? "",
            source: state.mode
        )
    }

    // MARK: - Paywall Content

    @ViewBuilder
    private func paywallContent(for generationState: GenerationState) -> some View {
        if let paywallType = state.paywallType {
            // Use aiResponse if available (segment-level operations), otherwise use simulated text
            let textToShow = state.aiResponse.isEmpty ? state.paywallSimulatedText : state.aiResponse
            QuickEditPaywallView(
                simulatedText: textToShow,
                paywallType: paywallType,
                source: state.mode
            )
        }
    }

    // MARK: - Normal Content

    @ViewBuilder
    private func normalContent(for generationState: GenerationState) -> some View {
        switch generationState {
        case .notStarted:
            // Don't show anything - waiting for user to submit prompt
            EmptyView()

        case .starting, .generating, .streaming:
            if selectionService.isRegenerating {
                // Show selectable text view with shimmer overlays on regenerating portions
                selectableResponseTextView
            } else if state.aiResponse.isEmpty {
                // Show empty shimmer placeholder while generating
                GeneratingShimmerView()
            } else {
                streamingResponseTextView
            }

        case .done:
            if let error = state.error {
                errorMessageView(error.localizedDescription)
            } else {
                selectableResponseTextView
            }
        }
    }

    // MARK: - Child Components

    private func loadingView(
        text: String,
        textColor: Color = Color.S_0
    ) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Loader()

            Text(text).styleText(
                size: 13,
                weight: .regular,
                color: textColor
            )
        }
        .padding(.top, hasProminentHeaderConfig ? 8 : 0)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func shimmeringTextView(text: String, isShimmering: Bool = true) -> some View {
        ScrollView {
            Text(text)
                .styleText(
                    size: fontSize,
                    weight: .regular,
                    color: textColor
                )
                .lineSpacing(lineHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    if isShimmering {
                        Rectangle()
                            .fill(textColor.opacity(0.1))
                            .shimmering()
                            .allowsHitTesting(false)
                    }
                }
        }
        .scrollClipDisabled(false)
        .frame(minHeight: promptTextFieldMinHeight, idealHeight: promptTextFieldMinHeight, maxHeight: promptTextFieldMaxHeight)
    }

    private func errorMessageView(_ errorMessage: String) -> some View {
        Text(errorMessage)
            .styleText(
                size: 13,
                weight: .regular,
                color: Color.orange500
            )
    }

    /// Response text view used during streaming (read-only)
    private var streamingResponseTextView: some View {
        DynamicScrollView(maxHeight: promptTextFieldMaxHeight) {
            Text(state.aiResponse)
                .styleText(
                    size: fontSize,
                    weight: .regular,
                    color: textColor
                )
                .lineSpacing(lineHeight)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// New selectable response text view with selection actions
    @ViewBuilder
    private var selectableResponseTextView: some View {
        SelectableTextView(
            text: displayedTextBinding,
            fontSize: fontSize,
            lineHeight: lineHeight,
            isEditable: true,
            frozenRanges: selectionService.frozenRanges,
            modifiedRanges: selectionService.modifiedRanges,
            regeneratingRanges: selectionService.regeneratingRanges,
            textColor: NSColor(textColor),
            maxHeight: promptTextFieldMaxHeight,
            isDiffMode: state.isDiffViewEnabled,
            diffSegments: diffService.diffSegments,
            onSelectionChange: { ranges, textView in
                handleSelectionChange(ranges, textView: textView)
            },
            onFrozenClick: { range, textView in
                handleFrozenClick(range, textView: textView)
            },
            onModifiedClick: { range, textView in
                handleModifiedClick(range, textView: textView)
            },
            onClickOutsideSelection: handleClickOutsideSelection,
            onRegeneratingRectsChange: { rects in
                DispatchQueue.main.async {
                    regeneratingRects = rects
                }
            },
            onHeightChange: { height in
                DispatchQueue.main.async {
                    textViewHeight = min(height, promptTextFieldMaxHeight)
                }
            },
            onDiffSegmentHover: { segment, textView in
                handleDiffSegmentHover(segment, textView: textView)
            },
            onDiffSegmentUnhover: {
                handleDiffSegmentUnhover()
            }
        )
        // Note: Don't use .id() with ranges as it recreates the view and loses focus
        // SelectableTextView.updateNSView handles range changes properly
        .frame(height: textViewHeight)
        .clipped()
        .overlay(alignment: .topLeading) {
            // Shimmer replacement for regenerating text (only show when actually regenerating)
            if !selectionService.regeneratingRanges.isEmpty {
                ForEach(Array(regeneratingRects.enumerated()), id: \.offset) { _, rect in
                    ShimmerLineView(rect: rect)
                        .allowsHitTesting(false)
                }
            }
        }
        .onHover { isHovering in
            QuickEditManager.shared.setWindowDraggingEnabled(!isHovering)
        }
        .onAppear {
            // Only initialize if the service is empty and has no frozen ranges
            // Don't reinitialize if we already have frozen text (to preserve frozen ranges)
            if selectionService.fullText.isEmpty && !selectionService.hasFrozenText {
                selectionService.initialize(with: state.aiResponse)
            }
        }
        .onChange(of: state.aiResponse) { oldValue, newValue in
            // Only update if the change came from outside (user edit or new generation)
            // Don't update if the service already has this text (to avoid resetting frozen ranges)
            if selectionService.fullText != newValue {
                selectionService.updateText(newValue)
            }

            // Recompute diff if diff view is enabled and response changed
            if state.isDiffViewEnabled, let originalText = state.selectedText {
                diffService.computeDiff(original: originalText, response: newValue)
            }
        }
    }

    // MARK: - Selection Handlers

    private func handleSelectionChange(_ ranges: [NSRange], textView: SelectableNSTextView?) {
        // Skip if we're in an operation that updates the text (to prevent hint from hiding)
        guard !selectionService.isUpdatingFromOperation else {
            return
        }

        selectionService.updateSelection(ranges)

        // Hide Un-freeze hint if visible
        selectionCoordinator.hideAllHints()

        // Check if we have a valid selection with at least one non-whitespace character
        guard let firstRange = ranges.first,
              firstRange.length > 0,
              let textView = textView else {
            return
        }

        // Get selected text and check for non-whitespace content
        let fullText = textView.string as NSString
        guard firstRange.location + firstRange.length <= fullText.length else { return }
        let selectedText = fullText.substring(with: firstRange)
        guard selectedText.contains(where: { !$0.isWhitespace }) else { return }

        // Get screen position for the hint
        if let screenRect = textView.screenRect(for: firstRange) {
            // Position hint above the selection
            let position = CGPoint(
                x: screenRect.midX,
                y: screenRect.maxY + 4
            )
            selectionCoordinator.showSelectionHint(at: position, for: firstRange)
        }
    }

    private func handleFrozenClick(_ range: NSRange, textView: SelectableNSTextView?) {
        // Hide selection hint
        selectionCoordinator.hideAllHints()

        // Get screen position for the hint
        if let textView = textView,
           let screenRect = textView.screenRect(for: range) {
            // Position hint above the frozen text
            let position = CGPoint(
                x: screenRect.midX,
                y: screenRect.maxY + 4
            )
            selectionCoordinator.showUnfreezeHint(at: position, for: range)
        }
    }

    private func handleModifiedClick(_ range: NSRange, textView: SelectableNSTextView?) {
        let selectionHint = SelectionHintWindowController.shared

        // Toggle behavior: if hint is visible for this range, hide it
        if selectionHint.isVisible, let associatedRange = selectionHint.associatedRange, NSEqualRanges(associatedRange, range) {
            selectionCoordinator.hideAllHints()
            selectionService.updateSelection([])
            return
        }

        // Hide any existing hints
        selectionCoordinator.hideAllHints()

        // Update selection to match the modified segment
        selectionService.updateSelection([range])

        // Get screen position for the hint
        if let textView = textView,
           let screenRect = textView.screenRect(for: range) {
            // Position hint above the modified text
            let position = CGPoint(
                x: screenRect.midX,
                y: screenRect.maxY + 4
            )
            selectionCoordinator.showModifiedHint(at: position, for: range)
        }
    }

    private func handleClickOutsideSelection() {
        // Skip if we're in an operation that updates the text (to prevent hint from hiding)
        guard !selectionService.isUpdatingFromOperation else {
            return
        }

        // Hide all hints
        selectionCoordinator.hideAllHints()
    }

    private func handleDiffSegmentHover(_ segment: DiffSegment, textView: SelectableNSTextView?) {
        // Handle hover on:
        // - All insert segments (swaps or pure inserts)
        // - All delete segments (standalone or paired - paired deletes redirect to their insert)
        let shouldShowHint: Bool
        switch segment.type {
        case .insert:
            shouldShowHint = true
        case .delete:
            // Show hint for all deletes - paired deletes will redirect undo to their insert
            shouldShowHint = true
        case .equal:
            shouldShowHint = false
        }

        guard shouldShowHint else { return }

        // Get screen position for the hint
        if let textView = textView,
           let screenRect = textView.screenRect(for: segment.range) {
            // Position hint above the diff segment
            let position = CGPoint(
                x: screenRect.midX,
                y: screenRect.maxY + 4
            )
            selectionCoordinator.showDiffUndoHint(at: position, for: segment)
        }
    }

    private func handleDiffSegmentUnhover() {
        // Hide the diff undo hint when mouse leaves the segment
        selectionCoordinator.hideDiffUndoHint()
    }
}
