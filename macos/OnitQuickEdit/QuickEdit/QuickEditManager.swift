//
//  QuickEditManager.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import AppKit
import Combine
import Defaults

@MainActor
class QuickEditManager: ObservableObject {

    // MARK: - Singleton

    static let shared = QuickEditManager()

    // MARK: - State

    let state = QuickEditState()

    // MARK: - Services

    let windowService = QuickEditWindowService()
    private lazy var displayService: QuickEditDisplayService = {
        QuickEditDisplayService(windowService: windowService, state: state)
    }()
    private let insertService = QuickEditInsertService()
    private let accessService = QuickEditAccessService.shared
    private let flowService = QuickEditFlowService.shared
    private var triggerService: QuickEditTriggerService?

    // MARK: - Hint Window

    let hintWindowController = QuickEditHintWindowController()

    // MARK: - Configuration

    @Default(.quickEditConfig) private var config

    // MARK: - Prompts

    let improvePrompt = """
        Improve the selected text while keeping my original voice and intent.
        - Fix spelling, grammar, and clarity issues
        - Make it more concise and easier to read without removing important details
        - Preserve personal touches, casual phrasing, and a friendly but professional tone
        - Do not sound robotic, overly polished, or like AI-written text
        - Avoid common AI tells (for example: em dashes, generic transitions, or corporate fluff)
        Style guidance:
        - Casual, direct, and human
        - Professional but approachable
        - Confident, not salesy
        Context awareness:
        - If the text is UI, website, or product copy, optimize it to be clear, compelling, and user-focused
        - If it's a message or note, prioritize natural flow and authenticity
        Output rules:
        - Do not add new information
        - Do not change the meaning
        - Return only the improved text
        Punctuation rules:
        - Do not use em dashes or dash-based sentence breaks of any kind
        - Rewrite sentences that would normally use an em dash using commas, periods, or parentheses instead
        - If an em dash appears in the input, remove it in the output
        """

    // MARK: - Current Request

    private(set) var currentRequest: QuickEditRequest?
    private var cancellables = Set<AnyCancellable>()
    private var isInserting = false // Flag to prevent window change detection during insertion
    private var clickOutsideMonitor: Any? // Event monitor for outside clicks

    // MARK: - Initialization

    private init() {
        // Set default QuickEdit model if none selected
        if Defaults[.quickEditRemoteModel] == nil {
            Defaults[.quickEditRemoteModel] = AIModel.quickEditDefault
        }
        setupShortcutObservers()
        setupAuthObserver()
        setupTriggerModeObserver()
    }

    private func setupShortcutObservers() {
        // Observe state changes to enable/disable shortcuts
        state.$isActivated
            .combineLatest(state.$isGenerating, state.$aiResponse)
            .sink { [weak self] isActivated, isGenerating, aiResponse in
                let shouldEnableInsert = isActivated && !isGenerating && !aiResponse.isEmpty
                
                if shouldEnableInsert {
                    KeyboardShortcutsManager.enableQuickEditShortcutsIfNeeded()
                } else {
                    KeyboardShortcutsManager.disableQuickEditShortcutsIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func setupAuthObserver() {
        // Observe auth state changes to retry after successful login
        AuthManager.shared.$account
            .dropFirst() // Skip initial value
            .sink { [weak self] account in
                guard let self = self else { return }
                let isLoggedIn = account != nil
                if isLoggedIn && self.state.isAuthWallActive {
                    self.retryAfterSuccessfulAuth()
                }
            }
            .store(in: &cancellables)
    }

    private func setupTriggerModeObserver() {
        // Observe trigger mode changes to restart services when switching between
        // accessibility and non-accessibility modes
        Defaults.publisher(.quickEditConfig)
            .map(\.newValue.enableNonAccessibilityTrigger)
            .removeDuplicates()
            .dropFirst() // Skip initial value (services haven't started yet)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Only restart if QuickEdit is enabled
                guard self.config.isEnabled else { return }

                print("[QuickEditManager] Trigger mode changed, restarting services...")
                self.stopListening()
                self.startListening()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startListening() {
        guard config.isEnabled else {
            return
        }

        // Use non-accessibility trigger if enabled (replaces standard trigger)
        if config.enableNonAccessibilityTrigger {
            // Stop accessibility trigger service if it was running
            triggerService?.stopListening()
            triggerService = nil

            let nonAccessibilityService = QuickEditNonAccessibilityTriggerService.shared
            nonAccessibilityService.delegate = self
            nonAccessibilityService.startMonitoring()
            print("[QuickEditManager] Using non-accessibility trigger service")
        } else {
            // Stop non-accessibility trigger service if it was running
            QuickEditNonAccessibilityTriggerService.shared.stopMonitoring()

            // Create standard trigger service (text selection mode only)
            triggerService = QuickEditTriggerService()
            triggerService?.delegate = self
            triggerService?.startListening()
            print("[QuickEditManager] Using accessibility trigger service")
        }

        // Add delegate for window change detection
        AccessibilityNotificationsManager.shared.addDelegate(self)

        // Add delegates for scroll and keystroke detection (to hide hint when position becomes invalid)
        MouseNotificationManager.shared.addDelegate(self)
        KeystrokeNotificationManager.shared.addDelegate(self)
    }

    func stopListening() {
        triggerService?.stopListening()
        triggerService = nil

        QuickEditNonAccessibilityTriggerService.shared.stopMonitoring()

        // Use hide() instead of hideQuickEdit() to also hide the hint
        // and disable QuickEdit global shortcuts (CMD+I, CMD+K)
        hide()

        // Remove delegates
        AccessibilityNotificationsManager.shared.removeDelegate(self)
        MouseNotificationManager.shared.removeDelegate(self)
        KeystrokeNotificationManager.shared.removeDelegate(self)
    }

    // MARK: - Public API

    /// Hides QuickEdit (both main window and hint)
    func hide() {
        hideQuickEdit()
        hideHint()
    }

    /// Starts AI generation with paywall check.
    /// Use this for new generation requests (Improve, custom prompts).
    /// - Parameter instruction: User's instruction
    func sendInstructionWithPaywallCheck(_ instruction: String) {
        state.generationState = .starting
        state.isActivated = true

        Task {
            do {
                let text = try await flowService.retrieveSelectedText(from: state)
                state.selectedText = text
                currentRequest?.selectedText = text
            } catch {
                state.error = error
                state.generationState = .done
                return
            }

            await startGenerationWithPaywallCheck(instruction: instruction)
        }
    }

    /// Checks access (auth + paywall) before any AI generation.
    /// Use this for segment-level operations (Retry, AI-Edit) that don't go through sendInstructionWithPaywallCheck.
    /// - Parameter pendingOperation: The operation to store and retry after successful auth/subscription
    /// - Returns: true if generation can proceed, false if blocked by auth wall or paywall
    func checkAccessBeforeGeneration(pendingOperation: PendingOperation? = nil) async -> Bool {
        let result = await accessService.checkAccess()

        if result.requiresAuth {
            state.isAuthWallActive = true
            state.pendingOperation = pendingOperation
            return false
        }

        if result.shouldShowPaywall, let paywallType = result.paywallType {
            state.isPaywallActive = true
            state.paywallType = paywallType
            state.pendingOperation = pendingOperation
            return false
        }

        return true
    }

    /// Internal method to check access (auth + paywall) and either show wall or perform real generation
    private func startGenerationWithPaywallCheck(instruction: String) async {
        // Check access status (auth + paywall)
        let result = await accessService.checkAccess()

        if result.requiresAuth {
            // Activate auth wall mode
            state.isAuthWallActive = true
            state.userInstruction = instruction
            state.pendingOperation = .generation(instruction: instruction)
            return
        }

        if result.shouldShowPaywall, let paywallType = result.paywallType {
            // Activate paywall mode
            state.isPaywallActive = true
            state.paywallType = paywallType
            state.userInstruction = instruction
            state.pendingOperation = .generation(instruction: instruction)

            // Simulate generation
            let textToSimulate = state.selectedText ?? ""
            state.paywallSimulatedText = ""

            await accessService.simulateGeneration(
                text: textToSimulate,
                onStateChange: { [weak self] newState in
                    self?.state.generationState = newState
                    if newState == .starting || newState == .generating {
                        self?.state.isGenerating = true
                    } else {
                        self?.state.isGenerating = false
                    }
                },
                onTextProgress: { [weak self] simulatedText in
                    self?.state.paywallSimulatedText = simulatedText
                }
            )
        } else {
            // Normal generation
            performGeneration(instruction: instruction)
        }
    }

    /// Performs the actual AI generation (internal implementation)
    private func performGeneration(instruction: String) {
        guard let request = currentRequest else {
            return
        }

        // Reset paywall state if it was active
        state.isPaywallActive = false
        state.paywallType = nil

        let selectionService = QuickEditSelectionService.shared
        let generationService = QuickEditGenerationService.shared

        // Initialize generation state
        state.generationState = .starting
        state.isGenerating = true
        state.userInstruction = instruction
        state.error = nil

        // Only clear aiResponse if there's no frozen text
        // When frozen text exists, we want to keep displaying it while regenerating non-frozen portions
        if !selectionService.hasFrozenText {
            state.aiResponse = ""
        }

        // Check if there's frozen text - if so, use global retry logic
        if selectionService.hasFrozenText {
            generationService.performGlobalRetry(
                instruction: instruction,
                context: request,
                state: state,
                onChunk: { [weak self] _ in
                    self?.state.aiResponse = selectionService.fullText
                }
            )
        } else {
            // Standard generation without frozen text
            generationService.performStandardGeneration(
                instruction: instruction,
                context: request,
                state: state,
                onChunk: { [weak self] chunk in
                    self?.state.aiResponse += chunk
                }
            )
        }
    }

    /// Inserts the generated response into the target application
    func insertResponse() async {
        guard !state.aiResponse.isEmpty else {
            return
        }

        // Check for demo mode - call callback with generated text instead of real insertion
        if state.isDemoMode {
            state.demoInsertCallback?(state.aiResponse)
            hideDemoHint()
            return
        }

        // Track result accepted
        AnalyticsManager.QuickEdit.resultAccepted()

        // Set flag to prevent window change detection during insertion
        isInserting = true

        // Save the content before switching windows
        let contentToInsert = state.aiResponse

        // Get the PID of the target application to send Cmd+V directly to it
        // This bypasses any floating panels that might capture the event
        var targetPid: pid_t?
        
        if let appName = state.currentAppName {
            let runningApps = NSWorkspace.shared.runningApplications
            
            if let app = runningApps.first(where: { $0.localizedName == appName }) {
                targetPid = app.processIdentifier
            }
        }

        // Insert the text directly to the target app
        await insertService.insertText(contentToInsert, targetPid: targetPid)

        // Reset flag and hide QuickEdit after insertion
        isInserting = false
        hideQuickEdit(reason: "completed")
    }

    /// Stops the current generation
    func stopGeneration() {
        QuickEditGenerationService.shared.cancelGeneration()
        state.isGenerating = false
        state.generationState = .done
    }

    /// Hides QuickEdit temporarily while auth is in progress
    /// Auth wall state is preserved so we can retry after successful auth
    func hideForAuth() {
        // Only hide the window, don't reset state (we need to preserve isAuthWallActive)
        windowService.hideWindow()
        state.isVisible = false
        state.isActivated = false
    }

    /// Called when user successfully authenticates
    /// Dismisses auth wall and retries the pending operation
    func retryAfterSuccessfulAuth() {
        guard state.isAuthWallActive else { return }

        let pendingOperation = state.pendingOperation

        // Track successful auth conversion
        let sourceString = modeToSourceString(state.mode)
        AnalyticsManager.QuickEdit.authWallConversion(source: sourceString)

        // Reset auth wall state
        state.isAuthWallActive = false
        state.pendingOperation = nil

        // Retry the pending operation with paywall check (user might still hit paywall)
        Task {
            await retryPendingOperationWithPaywallCheck(pendingOperation)
        }
    }

    /// Called when user successfully subscribes/upgrades via Stripe
    /// Dismisses paywall and retries the pending operation
    func retryAfterSuccessfulSubscription() {
        guard state.isPaywallActive else { return }

        let pendingOperation = state.pendingOperation

        // Track successful subscription conversion
        let paywallTypeString = state.paywallType == .freeLimit ? "free_limit" : "pro_limit"
        let sourceString = modeToSourceString(state.mode)
        AnalyticsManager.QuickEdit.paywallConversion(paywallType: paywallTypeString, source: sourceString)

        // Reset paywall state
        state.isPaywallActive = false
        state.paywallType = nil
        state.paywallSimulatedText = ""
        state.generationState = .notStarted
        state.isGenerating = false
        state.pendingOperation = nil

        // Retry the pending operation (without paywall check since we just subscribed)
        Task {
            await executePendingOperation(pendingOperation)
        }
    }

    /// Retries a pending operation with paywall check (used after auth)
    private func retryPendingOperationWithPaywallCheck(_ operation: PendingOperation?) async {
        guard let operation = operation else { return }

        switch operation {
        case .generation(let instruction):
            await startGenerationWithPaywallCheck(instruction: instruction)

        case .segmentRetry(let range):
            // Re-check access with paywall check
            let pendingOp = PendingOperation.segmentRetry(range: range)
            guard await checkAccessBeforeGeneration(pendingOperation: pendingOp) else { return }
            await QuickEditSelectionCoordinator.shared.executeSegmentRetry(range: range)

        case .segmentAIEdit(let range, let instruction):
            let pendingOp = PendingOperation.segmentAIEdit(range: range, instruction: instruction)
            guard await checkAccessBeforeGeneration(pendingOperation: pendingOp) else { return }
            await QuickEditSelectionCoordinator.shared.executeSegmentAIEdit(range: range, instruction: instruction)

        case .globalRetryWithFreezes(let instruction):
            let pendingOp = PendingOperation.globalRetryWithFreezes(instruction: instruction)
            guard await checkAccessBeforeGeneration(pendingOperation: pendingOp) else { return }
            executeGlobalRetryWithFreezes(instruction: instruction)
        }
    }

    /// Executes a pending operation directly (used after subscription, no paywall check needed)
    private func executePendingOperation(_ operation: PendingOperation?) async {
        guard let operation = operation else { return }

        switch operation {
        case .generation(let instruction):
            performGeneration(instruction: instruction)

        case .segmentRetry(let range):
            await QuickEditSelectionCoordinator.shared.executeSegmentRetry(range: range)

        case .segmentAIEdit(let range, let instruction):
            await QuickEditSelectionCoordinator.shared.executeSegmentAIEdit(range: range, instruction: instruction)

        case .globalRetryWithFreezes(let instruction):
            executeGlobalRetryWithFreezes(instruction: instruction)
        }
    }

    /// Executes global retry with frozen portions
    private func executeGlobalRetryWithFreezes(instruction: String) {
        guard let context = state.createQuickEditRequest() else { return }

        let selectionService = QuickEditSelectionService.shared

        state.isGenerating = true
        state.error = nil

        QuickEditGenerationService.shared.performGlobalRetry(
            instruction: instruction,
            context: context,
            state: state,
            onChunk: { [weak self] _ in
                self?.state.aiResponse = selectionService.fullText
            }
        )
    }

    /// Converts QuickEditMode to analytics source string
    private func modeToSourceString(_ mode: QuickEditMode?) -> String {
        switch mode {
        case .improve:
            return "improve"
        case .prompt:
            return "prompt"
        case .none:
            return "unknown"
        }
    }

    /// Makes the QuickEdit window editable (allows keyboard focus)
    func makeWindowEditable() {
        windowService.makeWindowEditable()
        state.isWindowKey = true
    }

    /// Enables or disables window dragging
    /// - Parameter enabled: true to enable dragging, false to disable
    func setWindowDraggingEnabled(_ enabled: Bool) {
        windowService.setDraggingEnabled(enabled)
    }

    // MARK: - Demo Mode

    /// Shows the hint in demo mode with real AI generation
    /// - Parameters:
    ///   - selectionBounds: Screen bounds of the selected text
    ///   - selectedText: The original selected text to improve
    ///   - onAction: Called when user clicks Improve or Edit (to update step indicator)
    ///   - onInsert: Called when user clicks Insert with the generated text (to update demo textbox)
    func showDemoHint(
        selectionBounds: CGRect,
        selectedText: String,
        onAction: @escaping (QuickEditMode) -> Void,
        onInsert: @escaping (String) -> Void
    ) {
        // Calculate display area (below the selection)
        let displayArea = calculateDemoDisplayArea(textFrame: selectionBounds)

        // Create a proper QuickEditRequest for demo mode
        let demoRequest = QuickEditRequest(
            applicationName: "Onit Demo",
            textBefore: nil,
            selectedText: selectedText,
            selectedTextBounds: selectionBounds,
            displayArea: displayArea,
            isDisplayedBelowHighlightedText: true,
            cursorTextFrame: selectionBounds
        )

        // Set up state for demo
        currentRequest = demoRequest
        state.isDemoMode = true
        state.selectedText = selectedText
        state.displayArea = displayArea
        state.isDisplayedBelowHighlightedText = true
        state.cursorTextFrame = selectionBounds
        state.currentAppName = "Onit Demo"
        state.currentAppBundleId = "com.synth.onit" // Demo mode uses Onit bundle ID
        state.isEditableElement = true
        state.demoActionCallback = onAction
        state.demoInsertCallback = onInsert

        // Position hint at the bottom-left of the selection
        let hintPosition = CGPoint(
            x: selectionBounds.minX,
            y: selectionBounds.minY
        )

        // Show the real hint directly (bypass config.showHint check for demo)
        hintWindowController.show(at: hintPosition, displayArea: displayArea)

        // Enable QuickEdit global shortcuts for demo mode
        KeyboardShortcutsManager.enableQuickEditGlobalShortcutsIfNeeded()
    }

    /// Calculates display area for demo mode (similar to QuickEditTriggerService)
    private func calculateDemoDisplayArea(textFrame: CGRect) -> CGRect {
        let uiWidth = QuickEditConstants.maxWindowWidth
        let maxExpandedHeight = QuickEditConstants.maxWindowHeight
        let padding = QuickEditConstants.windowPadding

        // Get screen bounds
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(textFrame.origin) }) ?? NSScreen.main else {
            return CGRect(
                x: textFrame.minX,
                y: textFrame.minY - maxExpandedHeight - padding,
                width: uiWidth,
                height: maxExpandedHeight
            )
        }

        let screenFrame = screen.visibleFrame
        let spaceBelow = textFrame.minY - screenFrame.minY

        if spaceBelow >= maxExpandedHeight + padding {
            // Display below text
            let frameMaxY = textFrame.minY - padding
            return CGRect(
                x: textFrame.minX,
                y: frameMaxY - maxExpandedHeight,
                width: uiWidth,
                height: maxExpandedHeight
            )
        } else {
            // Display above text
            return CGRect(
                x: textFrame.minX,
                y: textFrame.maxY + padding,
                width: uiWidth,
                height: maxExpandedHeight
            )
        }
    }

    /// Hides the demo hint and resets demo mode
    func hideDemoHint() {
        hideHint()
        displayService.hideQuickEdit()
        state.isDemoMode = false
        state.demoActionCallback = nil
        state.demoInsertCallback = nil
    }

    // MARK: - Hint Window Management

    /// Shows the hint window at the specified position
    /// - Parameter position: CGPoint position for the hint (bottom-left of the selected text)
    /// - Parameter displayArea: The display area where the main window will appear
    /// - Parameter smartHintPosition: When using smart positioning, this is the exact pre-calculated hint position
    func showHint(at position: CGPoint, displayArea: CGRect, smartHintPosition: CGRect? = nil) {
        guard config.showHint else { return }

        // Production build defers to dev build when both are running
        #if !DEBUG
        if DevBuildDetectionService.shared.shouldDeferToDevBuild {
            return
        }
        #endif
        hintWindowController.show(at: position, displayArea: displayArea, smartHintPosition: smartHintPosition)

        // Sync the positioning info from hint to state for main window
        state.isDisplayedBelowHighlightedText = hintWindowController.isDisplayedBelowHighlightedText

        // Enable QuickEdit global shortcuts when hint is visible
        KeyboardShortcutsManager.enableQuickEditGlobalShortcutsIfNeeded()

        // Start monitoring for clicks outside
        setupClickOutsideMonitor()
    }

    /// Hides the hint window
    func hideHint() {
        hintWindowController.hide()
        // Disable QuickEdit global shortcuts when hint is hidden
        KeyboardShortcutsManager.disableQuickEditGlobalShortcutsIfNeeded()

        // Stop monitoring clicks if no windows are visible
        if !state.isVisible {
            removeClickOutsideMonitor()
        }
    }

    /// Hides the hint and cancels any pending text selection
    /// - Parameter trigger: The reason for hiding (for debugging/analytics)
    private func hideHintAndCancelPendingSelection(trigger: String) {
        print("quickEditDebug - hint hide (trigger: \(trigger))")

        triggerService?.cancelPendingSelection()
        hideHint()
    }

    // MARK: - Configuration Methods

    /// Sets the current QuickEdit mode
    func setQuickEditMode(mode: QuickEditMode?) {
        state.mode = mode
    }

    /// Sets the header configuration
    func setQuickEditHeaderConfig(config: QuickEditHeaderConfig?) {
        state.headerConfig = config
    }


    // MARK: - Mode-Specific Methods

    /// Activates "Improve" mode and starts generation
    func improve() {
        // Hide the hint window if it's showing
        hideHint()

        // In demo mode, notify the callback but continue with real generation
        if state.isDemoMode {
            state.demoActionCallback?(.improve)
        }

        setQuickEditMode(mode: .improve)
        setQuickEditHeaderConfig(
            config: QuickEditHeaderConfig(
                icon: ImageResource(name: "wand", bundle: .main),
                title: String.localized("Improve", table: "QuickEdit"),
                isProminent: false,
                localizationKey: "Improve"
            )
        )

        // Activate QuickEdit
        state.isActivated = true
        state.generationState = .starting

        // Set generation state immediately to show loading UI while access check runs
        state.generationState = .starting

        // Make sure the main window is visible
        if !state.isVisible, let displayArea = state.displayArea {
            displayService.showQuickEdit(in: displayArea)
            // Setup click monitor when main window becomes visible
            setupClickOutsideMonitor()

            // Track QuickEdit opened via hint
            AnalyticsManager.QuickEdit.opened(trigger: "hint_improve")
        }

        // Make window key and activate app to accept button clicks immediately
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            makeWindowEditable()
        }

        Task {
            do {
                let text = try await flowService.retrieveSelectedText(from: state)
                state.selectedText = text
                currentRequest?.selectedText = text
            } catch {
                state.error = error
                state.generationState = .done
                return
            }

            // Use the built-in improve prompt from CustomPromptManager if available
            if let builtInImprove = CustomPromptManager.shared.customPrompts.first(where: { $0.id == CustomPrompt.builtInImproveID }) {
                await startGenerationWithPaywallCheck(instruction: builtInImprove.prompt)
            } else {
                await startGenerationWithPaywallCheck(instruction: improvePrompt)
            }
        }
    }

    /// Executes a custom prompt
    /// - Parameter prompt: The custom prompt to execute
    func executeCustomPrompt(_ prompt: CustomPrompt) {
        // Hide the hint window if it's showing
        hideHint()

        // In demo mode, notify the callback
        if state.isDemoMode {
            state.demoActionCallback?(.improve)
        }

        setQuickEditMode(mode: .improve)
        setQuickEditHeaderConfig(
            config: QuickEditHeaderConfig(
                sfSymbol: prompt.icon,
                title: prompt.localizedName,
                isProminent: false,
                localizationKey: prompt.id == CustomPrompt.builtInImproveID ? "Improve" : nil
            )
        )

        // Activate QuickEdit
        state.isActivated = true
        state.generationState = .starting

        // Make sure the main window is visible
        if !state.isVisible, let displayArea = state.displayArea {
            displayService.showQuickEdit(in: displayArea)
            // Setup click monitor when main window becomes visible
            setupClickOutsideMonitor()

            // Track QuickEdit opened via custom prompt
            AnalyticsManager.QuickEdit.opened(trigger: "hint_custom_prompt")
        }

        // Make window key and activate app to accept button clicks immediately
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            makeWindowEditable()
        }

        // Retrieve selected text and then start generation
        Task {
            do {
                let text = try await flowService.retrieveSelectedText(from: state)
                state.selectedText = text
                currentRequest?.selectedText = text
            } catch {
                state.error = error
                state.generationState = .done
                return
            }

            await startGenerationWithPaywallCheck(instruction: prompt.prompt)
        }
    }

    /// Activates "Prompt" mode (custom prompt)
    func prompt() {
        // Hide the hint window if it's showing
        hideHint()

        // In demo mode, notify the callback but continue with real prompt UI
        if state.isDemoMode {
            state.demoActionCallback?(.prompt)
        }

        setQuickEditMode(mode: .prompt)

        // Activate QuickEdit
        state.isActivated = true

        // Make sure the main window is visible
        if !state.isVisible, let displayArea = state.displayArea {
            displayService.showQuickEdit(in: displayArea)
            setupClickOutsideMonitor()

            // Track QuickEdit opened via hint
            AnalyticsManager.QuickEdit.opened(trigger: "hint_edit")
        }

        // Make window editable to receive keyboard input
        // Add a small delay to ensure the window and view are fully displayed
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            makeWindowEditable()
        }
    }

    // MARK: - Click Outside Monitor

    private func setupClickOutsideMonitor() {
        // Remove existing monitor if any
        removeClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }

            let clickLocation = NSEvent.mouseLocation

            // Check if click is inside hint window
            if let hintWindow = self.hintWindowController.window,
               hintWindow.isVisible,
               hintWindow.frame.contains(clickLocation) {
                return
            }

            // Check if click is inside main window
            if let mainWindow = self.windowService.windowController?.window,
               mainWindow.isVisible,
               mainWindow.frame.contains(clickLocation) {
                return
            }

            // Check if click is inside selection hint window
            if let selectionHintWindow = SelectionHintWindowController.shared.window,
               selectionHintWindow.isVisible,
               selectionHintWindow.frame.contains(clickLocation) {
                return
            }

            // Check if click is inside unfreeze hint window
            if let unfreezeHintWindow = UnfreezeHintWindowController.shared.window,
               unfreezeHintWindow.isVisible,
               unfreezeHintWindow.frame.contains(clickLocation) {
                return
            }

            // Don't hide if auth wall is active (user is authenticating)
            guard !self.state.isAuthWallActive else { return }

            // Click is outside all windows, hide UI
            Task { @MainActor in
                self.hideQuickEdit()
                self.hideHint()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Internal

    private func showQuickEdit(with request: QuickEditRequest) {
        currentRequest = request
        state.displayArea = request.displayArea
        state.isDisplayedBelowHighlightedText = request.isDisplayedBelowHighlightedText
        state.selectedText = request.selectedText
        state.contextText = request.textBefore
        state.cursorTextFrame = request.cursorTextFrame

        // Store application context
        state.currentAppName = request.applicationName
        state.currentAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        // isEditableElement hardcoded to true for v1 - detection was unreliable
        // state.isEditableElement = request.isEditableField

        // Store the selected text for later comparison
        if let selectedText = request.selectedText {
            state.lastProcessedHighlightedText = selectedText
        }

        state.isActivated = false

        if let selectedTextBounds = request.selectedTextBounds {
            showHint(
                at: selectedTextBounds.origin,
                displayArea: request.displayArea,
                smartHintPosition: request.smartHintPosition
            )
        }
    }

    private func hideQuickEdit(reason: String = "user_cancelled") {
        // Only track if QuickEdit was visible
        if state.isVisible {
            // Track result rejected if user closes without accepting (reason != "completed")
            if reason != "completed" && !state.aiResponse.isEmpty && state.generationState == .done {
                AnalyticsManager.QuickEdit.resultRejected()
            }

            AnalyticsManager.QuickEdit.closed(reason: reason)
        }

        displayService.hideQuickEdit()
        currentRequest = nil
        QuickEditGenerationService.shared.cancelGeneration()

        // Reset selection coordinator (hides hints and clears selection state)
        QuickEditSelectionCoordinator.shared.reset()

        // Reset state (but keep lastProcessedHighlightedText for change detection)
        let lastProcessed = state.lastProcessedHighlightedText
        state.reset()
        state.lastProcessedHighlightedText = lastProcessed

        // Remove click monitor when hiding
        removeClickOutsideMonitor()
    }

    // MARK: - Notification Observers

    private func handleWindowChange() {
        // Don't close QuickEdit if we're in the middle of inserting
        guard !isInserting else {
            return
        }

        guard state.isVisible else {
            return
        }

        hideQuickEdit(reason: "window_changed")
    }
}

// MARK: - QuickEditTriggerServiceDelegate

extension QuickEditManager: QuickEditTriggerServiceDelegate {
    func triggerQuickEdit(with request: QuickEditRequest) {
        // Check if QuickEdit is enabled via the unified FeatureDisableManager
        guard FeatureDisableManager.shared.isEnabled(.quickEdit) else {
            return
        }

        showQuickEdit(with: request)

        // Clear any "enable once" rules after QuickEdit is triggered
        FeatureDisableManager.shared.clearEnableOnceRules(for: .quickEdit)
    }

    func closeQuickEdit() {
        // Only close if currently visible
        guard state.isVisible else {
            return
        }

        hideQuickEdit()
    }
}

// MARK: - AccessibilityNotificationsDelegate

extension QuickEditManager: AccessibilityNotificationsDelegate {
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didActivateWindow window: TrackedWindow) {
        handleWindowChange()
    }

    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didActivateIgnoredWindow window: TrackedWindow?) {
        handleWindowChange()
    }

    // Required delegate properties
    var wantsNotificationsFromIgnoredProcesses: Bool { true }
    var wantsNotificationsFromOnit: Bool { true }

    // Required delegate methods - no-op implementations
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didChangeWindowTitle window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didChangeSelection element: AXUIElement, selectedText: String?) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didMoveWindow window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didResizeWindow window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didMinimizeWindow window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didDeminimizeWindow window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didDestroyWindow window: TrackedWindow) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didChangeFocusedUIElement element: AXUIElement) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didChangeValue element: AXUIElement) {}
    func accessibilityManager(_ manager: AccessibilityNotificationsManager, didDeactivateApplication appName: String?, processID: pid_t) {}
}

// MARK: - MouseNotificationDelegate

extension QuickEditManager: MouseNotificationDelegate {
    func mouseNotificationManager(_ manager: MouseNotificationManager, didScrollVertically deltaY: Double, deltaX: Double, event: CGEvent) {
        guard hintWindowController.isVisible else { return }
        
        hideHintAndCancelPendingSelection(trigger: "scroll")
    }

    func mouseNotificationManager(_ manager: MouseNotificationManager, didScroll deltaX: Double, deltaY: Double, event: CGEvent) {
        guard hintWindowController.isVisible else { return }
        
        hideHintAndCancelPendingSelection(trigger: "scroll")
    }
    
    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveSingleClick event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveDoubleClick event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveTripleClick event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didMove event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didStartDrag event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didUpdateDrag event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didEndDrag event: NSEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didScrollHorizontally deltaX: Double, deltaY: Double, event: CGEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didChangeScrollPhase phase: ScrollPhase, event: CGEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didChangeMomentumPhase phase: MomentumPhase, event: CGEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didBeginInertiaScroll event: CGEvent) {}
    func mouseNotificationManager(_ manager: MouseNotificationManager, didEndInertiaScroll event: CGEvent) {}
}

// MARK: - KeystrokeNotificationDelegate

extension QuickEditManager: KeystrokeNotificationDelegate {
    func keystrokeNotificationManager(_ manager: KeystrokeNotificationManager, didReceiveKeystroke event: KeystrokeEvent) {
        DispatchQueue.main.async { [weak self] in
            // Ignore modifier-only events (flagsChanged) — pressing CMD/Shift/etc alone
            // should not dismiss QuickEdit, only actual character keystrokes should.
            guard event.event.type == .keyDown else { return }

            // Only hide hint if it's visible and main window is not activated
            // When main window is activated, user is typing in the prompt field
            guard let self = self, self.hintWindowController.isVisible, !self.state.isActivated else { return }

            self.hideHintAndCancelPendingSelection(trigger: "keystroke")
        }
    }
}
