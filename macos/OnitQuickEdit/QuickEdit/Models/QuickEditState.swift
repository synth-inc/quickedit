//
//  QuickEditState.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import SwiftUI
import CoreGraphics
import GRDB

// MARK: - Supporting Types

/// Mode of operation for QuickEdit
enum QuickEditMode: String, Codable, DatabaseValueConvertible {
    case improve  // Uses predefined "improve" prompt
    case prompt   // Allows custom user prompt
}

/// Configuration for the QuickEdit header
struct QuickEditHeaderConfig {
    var icon: ImageResource? = nil
    var sfSymbol: String? = nil
    var iconSize: CGFloat = 13
    var title: String
    var isProminent: Bool
    var localizationKey: String? = nil

    /// Creates a header config from an instruction title, automatically setting the wand icon for "Improve"
    static func fromInstruction(_ instruction: String?) -> QuickEditHeaderConfig {
        let title = instruction ?? "Improve"
        let isImprove = title == "Improve"

        return QuickEditHeaderConfig(
            icon: isImprove ? ImageResource(name: "wand", bundle: .main) : nil,
            title: title,
            isProminent: !isImprove
        )
    }
}

/// Observable state for QuickEdit UI
@MainActor
class QuickEditState: ObservableObject {
    // MARK: - UI State

    /// Whether the QuickEdit UI is currently visible
    @Published var isVisible: Bool = false

    /// Whether AI is currently generating a response
    @Published var isGenerating: Bool = false

    /// Whether QuickEdit is activated (expanded mode vs compact mode)
    @Published var isActivated: Bool = false

    /// Whether the window is currently key (has focus)
    @Published var isWindowKey: Bool = false

    // MARK: - Display Information

    /// Area where the UI should be displayed (from accessibility bounds)
    @Published var displayArea: CGRect?

    /// Whether the UI is displayed below the highlighted text (true) or above (false)
    @Published var isDisplayedBelowHighlightedText: Bool = true

    /// Frame of the text cursor area for positioning reference
    @Published var cursorTextFrame: CGRect?

    // MARK: - Content

    /// User's instruction/prompt (e.g., "Correct grammar", "Make it shorter")
    @Published var userInstruction: String = ""

    /// Current text in the prompt input field (cleared on dismiss)
    @Published var promptInputText: String = ""

    /// AI-generated response (streamed in real-time)
    @Published var aiResponse: String = ""

    /// Text that was selected by the user
    @Published var selectedText: String?

    /// Additional context text (text before/after cursor from accessibility)
    @Published var contextText: String?

    /// Last highlighted text that was processed (to detect changes)
    @Published var lastProcessedHighlightedText: String?

    // MARK: - Mode and Generation State (from Loyd's branch)

    /// Current mode of operation (improve or custom prompt)
    @Published var mode: QuickEditMode?

    /// Current state of the AI generation process
    @Published var generationState: GenerationState = .notStarted

    /// Configuration for the header display
    @Published var headerConfig: QuickEditHeaderConfig?


    // MARK: - Application Context (from Loyd's branch)

    /// Name of the application where text was selected
    @Published var currentAppName: String?

    /// Bundle ID of the application where text was selected
    @Published var currentAppBundleId: String?

    /// Whether the current element is editable
    /// Hardcoded to true for v1 - detection was unreliable
    @Published var isEditableElement: Bool = true

    // MARK: - Auth Wall State

    /// Whether the auth wall is currently active (user not logged in)
    @Published var isAuthWallActive: Bool = false

    // MARK: - Paywall State

    /// Whether the paywall is currently active
    @Published var isPaywallActive: Bool = false

    /// Type of paywall to display
    @Published var paywallType: QuickEditPaywallType?

    /// Simulated text during paywall generation
    @Published var paywallSimulatedText: String = ""

    /// Operation that was blocked by auth/paywall and needs to be retried after successful auth/subscription
    var pendingOperation: PendingOperation?

    // MARK: - Demo Mode

    /// Whether QuickEdit is in demo mode (for onboarding)
    /// In demo mode, real AI generation happens but insert updates the demo textbox instead of pasting
    @Published var isDemoMode: Bool = false

    /// Callback for demo mode actions (Improve/Edit clicked) - notifies step change
    var demoActionCallback: ((QuickEditMode) -> Void)?

    /// Callback for demo mode insert action - receives the generated text to update demo textbox
    var demoInsertCallback: ((String) -> Void)?

    // MARK: - Error State

    /// Current error, if any
    @Published var error: Error?

    /// Whether the server is currently initializing
    @Published var isServerInitializing: Bool = false

    // MARK: - Diff View State

    /// Height of the diff notification banner
    static let diffNotificationHeight: CGFloat = 32

    /// Whether the diff view is currently enabled
    @Published var isDiffViewEnabled: Bool = false

    /// Whether the diff notification banner has been dismissed by the user
    @Published var isDiffNotificationDismissed: Bool = false

    /// Whether the diff notification should be visible (diff enabled AND not dismissed)
    var isDiffNotificationVisible: Bool {
        isDiffViewEnabled && !isDiffNotificationDismissed
    }

    // MARK: - Prompt History State

    /// Original text typed by the user (preserved during history navigation)
    @Published var originalPromptText: String = ""

    /// Current list of prompt suggestions from history search
    @Published var promptHistorySuggestions: [ScoredPromptHistoryEntry] = []

    /// Currently selected index in the prompt history list (-1 = none selected, in TextField)
    @Published var promptHistorySelectedIndex: Int = -1

    /// Whether the user is currently navigating through prompt history
    @Published var isInPromptHistoryNavigation: Bool = false

    /// Whether hover events should be respected (only after mouse has moved)
    @Published var shouldRespectHover: Bool = false

    // Show chat when:
    // - Auth/paywall wall is active, OR
    // - Activated AND (generation has started OR mode is .improve)
    var shouldShowChat: Bool {
        return
            isAuthWallActive ||
            isPaywallActive ||
            (isActivated && (generationState != .notStarted || mode == .improve))
    }


    // MARK: - Reset

    /// Reset the state to initial values (called when hiding UI)
    func reset() {
        // Cancel any pending generation first, before clearing context
        // This ensures the task receives CancellationError instead of a context error
        QuickEditGenerationService.shared.cancelGeneration()

        isVisible = false
        isGenerating = false
        isActivated = false
        isWindowKey = false
        displayArea = nil
        cursorTextFrame = nil
        userInstruction = ""
        promptInputText = ""
        aiResponse = ""
        selectedText = nil
        contextText = nil
        error = nil

        // Reset new properties from Loyd's branch
        mode = nil
        generationState = .notStarted
        headerConfig = nil
        currentAppName = nil
        currentAppBundleId = nil
        isEditableElement = true  // Hardcoded to true for v1

        // Reset prompt history state
        originalPromptText = ""
        promptHistorySuggestions = []
        promptHistorySelectedIndex = -1
        isInPromptHistoryNavigation = false
        shouldRespectHover = false

        // Reset conversation history navigation state
        QuickEditConversationHistoryManager.shared.exitNavigation()

        // Reset auth wall state
        isAuthWallActive = false

        // Reset paywall state
        isPaywallActive = false
        paywallType = nil
        paywallSimulatedText = ""
        pendingOperation = nil

        // Reset diff view state
        isDiffViewEnabled = false
        isDiffNotificationDismissed = false
        
		// Reset demo mode
        isDemoMode = false
        demoActionCallback = nil
        demoInsertCallback = nil
    }

    // MARK: - Prompt History Helpers

    /// Whether to show the prompt history dropdown
    var shouldShowPromptHistory: Bool {
        return !promptHistorySuggestions.isEmpty
    }

    /// Resets prompt history navigation state
    func resetPromptHistoryNavigation() {
        promptHistorySelectedIndex = -1
        isInPromptHistoryNavigation = false
    }

    // MARK: - Context Creation

    /// Creates a QuickEditRequest from the current state
    /// Used by both QuickEditChatToolbar and QuickEditSelectionCoordinator
    func createQuickEditRequest() -> QuickEditRequest? {
        guard let selectedText = selectedText else { return nil }

        return QuickEditRequest(
            applicationName: currentAppName ?? "Unknown",
            textBefore: contextText,
            selectedText: selectedText,
            selectedTextBounds: nil,
            displayArea: displayArea ?? .zero,
            isDisplayedBelowHighlightedText: isDisplayedBelowHighlightedText,
            cursorTextFrame: cursorTextFrame ?? .zero
        )
    }
}

// MARK: - Paywall Type

/// Type of paywall to display in QuickEdit
enum QuickEditPaywallType: Equatable {
    /// Free plan user has used all free edits
    case freeLimit
    /// Pro plan user has reached monthly limit
    case proLimit
}

// MARK: - Pending Operation

/// Represents an operation that was blocked by auth/paywall and needs to be retried
enum PendingOperation {
    /// Standard generation with instruction (Improve, custom prompt)
    case generation(instruction: String)
    /// Retry on a specific segment
    case segmentRetry(range: NSRange)
    /// AI-Edit on a specific segment
    case segmentAIEdit(range: NSRange, instruction: String)
    /// Global retry with frozen portions
    case globalRetryWithFreezes(instruction: String)
}
