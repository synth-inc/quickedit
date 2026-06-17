//
//  QuickEditPromptToolbar.swift
//  Onit
//
//  Created by Loyd Kim on 11/20/25.
//

import SwiftUI
import Combine
import Defaults

struct QuickEditPromptToolbar: View {
    // MARK: - Properties

    @ObservedObject var state: QuickEditState
    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Defaults

    @Default(.quickEditShowHistoryWithoutTyping) private var showHistoryWithoutTyping

    // MARK: - States
    
    @ObservedObject private var conversationHistoryManager = QuickEditConversationHistoryManager.shared

    @FocusState private var isPromptTextFieldFocused: Bool

    @State private var promptTextFieldPlaceholder: String = String.localized("Describe any changes...", table: "QuickEdit")
    @State private var sendButtonIsHovered: Bool = false
    @State private var sendButtonIsPressed: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var keyDownMonitor: Any?
    @State private var mouseMovedMonitor: Any?
    @State private var lastMouseLocation: CGPoint?

    /// Whether the prompt history container is expanded (for frame animation)
    @State private var isPromptHistoryExpanded: Bool = false

    // MARK: - Private Variables

    private var shouldShow: Bool {
        // Always show in both modes (prompt and improve)
        // Disabled state is handled separately during generation
        return !state.isPaywallActive && !state.isAuthWallActive
    }

    private var shouldNavigatePromptHistory: Bool {
        return !state.promptInputText.isEmpty && state.shouldShowPromptHistory && state.generationState == .notStarted
    }
    
    private var hasConversationHistory: Bool {
        guard let currentConversations = self.conversationHistoryManager.conversations
        else {
            return false
        }
              
        return !currentConversations.isEmpty
    }
    
    private var shouldNavigateConversationHistory: Bool {
        guard self.hasConversationHistory else { return false }
        
        return
            state.promptInputText.isEmpty &&
            !self.shouldNavigatePromptHistory &&
            (state.generationState == .notStarted || state.generationState == .done)
    }

    private var isLoadingPromptGeneration: Bool {
        return state.generationState == .generating || state.generationState == .streaming
    }

    private var canSubmitPrompt: Bool {
        if state.promptInputText.isEmpty {
            return false
        }
        return state.generationState == .notStarted || state.generationState == .done
    }

    private var sendButtonBackground: Color {
        if canSubmitPrompt {
            return Color.S_0
        } else {
            return Color.T_6
        }
    }

    private var sendButtonEnabled: Bool {
        return isLoadingPromptGeneration || canSubmitPrompt
    }

    /// Direction key to enter history list (always up arrow since history is always above TextField)
    private var upArrowKey: UInt16 {
        return 126
    }

    /// Direction key to exit history list back to TextField (always down arrow)
    private var downArrowKey: UInt16 {
        return 125
    }

    /// Duration of the frame expansion animation
    private let frameAnimationDuration: Double = 0.18

    // MARK: - Body

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 0) {
                // History list always above TextField
                // Two-phase animation: first expand frame, then fade in rows
                if isPromptHistoryExpanded {
                    promptHistoryList
                        .padding(.vertical, 4)
                }

                // Divider above TextField when there's content above it
                let hasChatContent = state.isActivated && (state.generationState != .notStarted || state.mode == .improve)
                let hasContentAboveTextField = hasChatContent || isPromptHistoryExpanded

                if hasContentAboveTextField {
                    DividerHorizontal(foregroundColor: Color.T_7)
                        .padding(.bottom, 10)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                }

                HStack(alignment: .center, spacing: 8) {
                    promptTextField

                    sendButton
                }
                .padding(.horizontal, 10)
            }
            .onChange(of: shouldNavigatePromptHistory) { _, shouldNavigatePromptHistory in
                withAnimation(.spring(response: frameAnimationDuration, dampingFraction: 0.9)) {
                    isPromptHistoryExpanded = shouldNavigatePromptHistory
                }
            }
            .onAppear {
                installKeyDownMonitor()
                installMouseMovementMonitor()
            }
            .onDisappear {
                removeKeyDownMonitor()
                removeMouseMovementMonitor()
                searchTask?.cancel()
            }
            .onChange(of: shouldShow) { _, newValue in
                if newValue {
                    installKeyDownMonitor()
                    installMouseMovementMonitor()
                    // Reset hover state when UI becomes visible
                    state.shouldRespectHover = false
                } else {
                    removeKeyDownMonitor()
                    removeMouseMovementMonitor()
                }
            }
            .id(localization.currentLanguage)
        }
    }

    // MARK: - Child Components

    @ViewBuilder
    private var promptTextField: some View {
        if isLoadingPromptGeneration || state.generationState == .starting {
            generatingTextView
        } else {
            editableTextField
        }
    }
    
    private struct BouncingEllipses: View {
        @State private var shouldAnimate = false

        private let dotCount: Int = 3
        private let bounceDelay: TimeInterval = 0.18
        private let bounceDuration: TimeInterval = 0.32
        private let pauseDuration: TimeInterval = 0.20

        private var cycleDuration: TimeInterval {
            let lastDelay = TimeInterval(self.dotCount - 1) * self.bounceDelay
            let downUp = self.bounceDuration * 2
            return lastDelay + downUp
        }

        var body: some View {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<self.dotCount, id: \.self) { index in
                    Circle()
                        .fill(Color.S_0)
                        .frame(width: 2, height: 2)
                        .offset(y: self.shouldAnimate ? 0 : 2)
                        .opacity(self.shouldAnimate ? 0.4 : 0)
                        .animation(
                            .easeInOut(duration: self.bounceDuration).delay(Double(index) * self.bounceDelay),
                            value: self.shouldAnimate
                        )
                }
            }
            .task {
                while !Task.isCancelled {
                    self.shouldAnimate = true
                    try? await Task.sleep(nanoseconds: UInt64(self.cycleDuration * 1_000_000_000))

                    self.shouldAnimate = false
                    try? await Task.sleep(nanoseconds: UInt64(self.pauseDuration * 1_000_000_000))
                }
            }
        }
    }

    private var generatingTextView: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Text(String.localized("Generating", table: "QuickEdit"))
                .styleText(weight: .regular, color: Color.S_0.opacity(0.4))
            
            BouncingEllipses()
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editableTextField: some View {
        TextField(
            "",
            text: $state.promptInputText,
            prompt: Text(promptTextFieldPlaceholder).foregroundColor(Color.S_0.opacity(0.4))
        )
        .textFieldStyle(PlainTextFieldStyle())
        .styleText(weight: .regular)
        .focused($isPromptTextFieldFocused)
        .onAppear {
            // Reset text field state
            state.promptInputText = ""
            state.promptHistorySuggestions = []
            state.resetPromptHistoryNavigation()

            // Set focus when TextField appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPromptTextFieldFocused = true
            }

            // Load recent suggestions immediately if setting is enabled
            if showHistoryWithoutTyping {
                loadInitialSuggestions()
            }
        }
        .onChange(of: shouldShow) { _, newValue in
            // Set focus when TextField becomes visible (after window becomes key)
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPromptTextFieldFocused = true
                }
            }
        }
        .onChange(of: state.isWindowKey) { _, isKey in
            // Set focus when window becomes key
            if isKey && shouldShow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPromptTextFieldFocused = true
                }
            }
        }
        .onChange(of: state.generationState) { _, generationState in
            if generationState == .done {
                state.promptInputText = ""
                // Clear prompt history after generation - only show history on initial prompt
                state.resetPromptHistoryNavigation()
                state.promptHistorySuggestions = []
            }
        }
        .onChange(of: state.promptInputText) { oldValue, newValue in
            handlePromptInstructionChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: self.hasConversationHistory, initial: true) { _, hasConversationHistory in
            promptTextFieldPlaceholder = state.generationState == .done
                ? String.localized("Ask for any changes", table: "QuickEdit") + (hasConversationHistory ? " " + String.localized("or ↑↓ for history", table: "QuickEdit") : "...")
                : String.localized("Describe changes", table: "QuickEdit") + (hasConversationHistory ? " " + String.localized("or ↑↓ for history", table: "QuickEdit") : "...")
        }
        .onSubmit {
            handleSubmit()
        }
        .onTapGesture {
            // Clicking on TextField restores original text and exits navigation
            if state.isInPromptHistoryNavigation {
                state.promptInputText = state.originalPromptText
                state.resetPromptHistoryNavigation()
            }
        }
    }

    private var promptHistoryList: some View {
        QuickEditPromptHistoryListView(
            suggestions: state.promptHistorySuggestions,
            selectedIndex: state.promptHistorySelectedIndex,
            onSelect: { entry in
                selectHistoryEntry(entry)
            },
            onDelete: { entry in
                deleteHistoryEntry(entry)
            },
            onHover: { index in
                // Only respect hover if the user has explicitly moved the mouse
                guard state.shouldRespectHover else { return }
                // index of -1 means hover ended, clear selection
                state.promptHistorySelectedIndex = index
            }
        )
    }

    private var sendButtonArrowIcon: some View {
        Image(.arrowDown)
            .addIconStyles(
                foregroundColor: canSubmitPrompt ? Color.S_10 : Color.S_1,
                iconSize: 14
            )
            .frame(width: 20, alignment: .center)
            .frame(height: 20, alignment: .center)
            .rotationEffect(.degrees(180))
    }

    @ViewBuilder
    private var sendButtonIcon: some View {
        switch state.generationState {

        case .starting:
            Loader(size: 20)

        case .generating, .streaming:
            Image(.stop)
                .addIconStyles(
                    foregroundColor: Color.S_0.opacity(sendButtonIsHovered ? 0.7 : 1),
                    iconSize: 20
                )

        case .notStarted, .done:
            sendButtonArrowIcon
        }
    }

    private var sendButton: some View {
        sendButtonIcon
            .addButtonEffects(
                background: sendButtonBackground,
                hoverBackground: sendButtonBackground.opacity(0.7),
                cornerRadius: 999,
                isHovered: $sendButtonIsHovered,
                isPressed: $sendButtonIsPressed
            ) {
                if isLoadingPromptGeneration {
                    stopGeneration()
                } else if canSubmitPrompt {
                    submitPrompt()
                }
            }
            .addAnimation(dependency: sendButtonEnabled)
            .disabled(!sendButtonEnabled)
            .allowsHitTesting(sendButtonEnabled)
    }

    // MARK: - Private Functions

    private func stopGeneration() {
        QuickEditManager.shared.stopGeneration()
    }

    private func submitPrompt(overrideText: String? = nil) {
        let textToSubmit = overrideText ?? state.promptInputText

        // Save prompt to history before submitting
        Task {
            await QuickEditPromptHistoryManager.shared.savePrompt(
                text: textToSubmit,
                appName: state.currentAppName
            )
        }

        QuickEditManager.shared.setQuickEditHeaderConfig(
            config: QuickEditHeaderConfig(
                title: textToSubmit,
                isProminent: true
            )
        )
        
        QuickEditManager.shared.setQuickEditMode(mode: .prompt)

        // Use paywall-checked version for new prompts
        QuickEditManager.shared.sendInstructionWithPaywallCheck(textToSubmit)
    }

    // MARK: - Prompt History Functions

    private func handlePromptInstructionChange(oldValue: String, newValue: String) {
        // Don't search during generation or after a response has been generated
        guard !isLoadingPromptGeneration && state.generationState == .notStarted else { return }

        // If user is in navigation mode and the text changes to something different
        // than the selected item's text, it means user is typing - exit navigation
        if state.isInPromptHistoryNavigation && state.promptHistorySelectedIndex >= 0 {
            let selectedText = state.promptHistorySuggestions[state.promptHistorySelectedIndex].text
            if newValue != selectedText {
                // User is typing, exit navigation mode
                state.resetPromptHistoryNavigation()
                state.originalPromptText = newValue
            } else {
                // Text matches selected item (came from navigation), don't re-search
                return
            }
        }

        // Store original text when user types
        if !state.isInPromptHistoryNavigation {
            state.originalPromptText = newValue
        }

        // Cancel previous search
        searchTask?.cancel()

        // Check minimum character requirement
        let minChars = showHistoryWithoutTyping ? 0 : QuickEditPromptHistoryConfig.minCharactersForSearch
        guard newValue.count >= minChars else {
            state.promptHistorySuggestions = []
            state.resetPromptHistoryNavigation()
            return
        }

        // Debounce search (or load recent if empty)
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce

            guard !Task.isCancelled else { return }

            let results = await QuickEditPromptHistoryManager.shared.searchPrompts(
                query: newValue,
                currentAppName: state.currentAppName
            )

            await MainActor.run {
                guard !Task.isCancelled else { return }
                state.promptHistorySuggestions = results
                // Reset selection when results change
                state.promptHistorySelectedIndex = -1
                state.isInPromptHistoryNavigation = false
            }
        }
    }

    private func loadInitialSuggestions() {
        searchTask?.cancel()
        searchTask = Task {
            let results = await QuickEditPromptHistoryManager.shared.searchPrompts(
                query: "",
                currentAppName: state.currentAppName
            )

            await MainActor.run {
                state.promptHistorySuggestions = results
            }
        }
    }

    private func handleSubmit() {
        if state.isInPromptHistoryNavigation && state.promptHistorySelectedIndex >= 0 {
            // If navigating history, select the current item
            let selectedEntry = state.promptHistorySuggestions[state.promptHistorySelectedIndex]
            selectHistoryEntry(selectedEntry)
        } else if canSubmitPrompt {
            // Normal submit
            submitPrompt()
        }
    }

    private func selectHistoryEntry(_ entry: ScoredPromptHistoryEntry) {
        // Set generation state FIRST to show generating UI state
        state.generationState = .starting

        // Clear history UI
        state.promptHistorySuggestions = []
        state.resetPromptHistoryNavigation()

        // Submit directly with the entry text
        submitPrompt(overrideText: entry.text)
    }

    private func deleteHistoryEntry(_ entry: ScoredPromptHistoryEntry) {
        guard let entryId = entry.id else { return }

        Task {
            await QuickEditPromptHistoryManager.shared.deletePrompt(id: entryId)

            // Restore original text
            await MainActor.run {
                state.promptInputText = state.originalPromptText

                // Re-search to update the list
                if state.originalPromptText.count >= QuickEditPromptHistoryConfig.minCharactersForSearch {
                    searchTask = Task {
                        let results = await QuickEditPromptHistoryManager.shared.searchPrompts(
                            query: state.originalPromptText,
                            currentAppName: state.currentAppName
                        )

                        await MainActor.run {
                            state.promptHistorySuggestions = results
                            state.promptHistorySelectedIndex = -1
                            state.isInPromptHistoryNavigation = false
                        }
                    }
                } else {
                    state.promptHistorySuggestions = []
                    state.resetPromptHistoryNavigation()
                }
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func installKeyDownMonitor() {
        // Remove existing monitor first to avoid duplicates
        removeKeyDownMonitor()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            return self.handleKeyDown(event: event)
        }
    }

    private func removeKeyDownMonitor() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }

    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        // Only handle when we're in prompt mode and have suggestions
        guard shouldShow else { return event }

        let keyCode = event.keyCode

        // Arrow key handling
        if keyCode == 125 || keyCode == 126 { // Down (125) or Up (126)
            return handleArrowKey(keyCode: keyCode, event: event)
        }

        // Escape handling - close history suggestions
        if keyCode == 53 { // Escape
            if self.conversationHistoryManager.isNavigatingHistory {
                self.conversationHistoryManager.exitNavigation()
                self.clearConversationFromState()
                return nil
            }
            
            if state.shouldShowPromptHistory {
                // Restore original text and clear suggestions
                state.promptInputText = state.originalPromptText
                state.promptHistorySuggestions = []
                state.resetPromptHistoryNavigation()
                return nil // Consume the event
            }
        }

        return event
    }

    private func handleArrowKey(keyCode: UInt16, event: NSEvent) -> NSEvent? {
        if self.shouldNavigatePromptHistory {
            return self.handlePromptHistoryNavigation(keyCode: keyCode, event: event)
        } else if self.shouldNavigateConversationHistory {
            return self.handleConversationHistoryNavigation(keyCode: keyCode, event: event)
        } else {
            return event
        }
    }
    
    // MARK: - Keyboard Navigation Helpers
    
    private func handlePromptHistoryNavigation(
        keyCode: UInt16,
        event: NSEvent
    ) -> NSEvent? {
        let maxIndex = state.promptHistorySuggestions.count - 1

        // Enter navigation from TextField
        if keyCode == upArrowKey {
            if state.promptHistorySelectedIndex == -1 {
                // Not in navigation yet, enter it
                state.isInPromptHistoryNavigation = true
                state.promptHistorySelectedIndex = 0
                // Update TextField with preview
                if !state.promptHistorySuggestions.isEmpty {
                    state.promptInputText = state.promptHistorySuggestions[0].text
                }
                return nil // Consume event
            } else if state.promptHistorySelectedIndex < maxIndex {
                // Move down in the list
                state.promptHistorySelectedIndex += 1
                state.promptInputText = state.promptHistorySuggestions[state.promptHistorySelectedIndex].text
                return nil
            }
        }

        // Exit navigation back to TextField
        if keyCode == downArrowKey {
            if state.promptHistorySelectedIndex == 0 {
                // At top of list, go back to TextField
                state.promptInputText = state.originalPromptText
                state.resetPromptHistoryNavigation()
                return nil
            } else if state.promptHistorySelectedIndex > 0 {
                // Move up in the list
                state.promptHistorySelectedIndex -= 1
                state.promptInputText = state.promptHistorySuggestions[state.promptHistorySelectedIndex].text
                return nil
            }
        }

        return event
    }
    
    private func applyConversationToState(_ conversation: QuickEditConversationHistoryEntry) {
        state.isActivated = true
        state.userInstruction = conversation.userInstruction ?? ""
        state.aiResponse = conversation.aiResponse
        state.selectedText = conversation.selectedText
        state.mode = conversation.mode
        state.generationState = .done

        /// Restoring global snapshots.
        if let globalSnapshots = conversation.globalSnapshots,
           !globalSnapshots.isEmpty
        {
            QuickEditSelectionService.shared.restoreSnapshots(from: globalSnapshots)

            let headerTitle =
                QuickEditSelectionService.shared.currentSnapshot?.instruction ??
                conversation.userInstruction

            state.headerConfig = .fromInstruction(headerTitle)
        } else {
            state.headerConfig = .fromInstruction(conversation.userInstruction)
        }
    }

    private func clearConversationFromState() {
        state.isActivated = false
        state.aiResponse = ""
        state.generationState = .notStarted
        state.headerConfig = nil
        
        QuickEditSelectionService.shared.reset()
    }
    
    private func handleConversationHistoryNavigation(
        keyCode: UInt16,
        event: NSEvent
    ) -> NSEvent? {
        /// Up arrow = Navigate to older conversations.
        if keyCode == self.upArrowKey {
            /// Initialize conversation history navigation by starting at the most recent conversation.
            if !self.conversationHistoryManager.isNavigatingHistory {
                if let conversation = self.conversationHistoryManager.startNavigation() {
                    self.applyConversationToState(conversation)
                }
                return nil
            }
            /// Navigate to older conversations.
            else {
                Task {
                    if let previousConversation = await self.conversationHistoryManager.navigateToPreviousConversation() {
                        self.applyConversationToState(previousConversation)
                    }
                }
                return nil
            }
        }

        /// Down arrow = Navigate to newer conversations or exit navigation.
        else if keyCode == self.downArrowKey {
            if self.conversationHistoryManager.isNavigatingHistory {
                /// Go to next conversation in history if it exists.
                if let nextConversation = self.conversationHistoryManager.navigateToNextConversation() {
                    self.applyConversationToState(nextConversation)
                }
                /// Otherwise, we're already at the most recent, so exit navigation.
                else {
                    self.conversationHistoryManager.exitNavigation()
                    self.clearConversationFromState()
                }
                return nil
            }
        }

        return event
    }

    // MARK: - Mouse Movement Tracking

    private func installMouseMovementMonitor() {
        // Store the initial mouse location
        lastMouseLocation = NSEvent.mouseLocation

        // Monitor mouse movement events
        mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            handleMouseMoved()
            return event
        }
    }

    private func removeMouseMovementMonitor() {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
        lastMouseLocation = nil
    }

    private func handleMouseMoved() {
        let currentLocation = NSEvent.mouseLocation

        // Check if the mouse has actually moved from its last known position
        if let lastLocation = lastMouseLocation {
            let deltaX = abs(currentLocation.x - lastLocation.x)
            let deltaY = abs(currentLocation.y - lastLocation.y)

            // Only enable hover if the mouse has moved at least 2 points
            // This helps avoid minor jitter
            if deltaX > 2 || deltaY > 2 {
                state.shouldRespectHover = true
            }
        } else {
            // First movement, enable hover
            state.shouldRespectHover = true
        }

        lastMouseLocation = currentLocation
    }
}
