//
//  QuickEditFlowService.swift
//  Onit
//
//  Coordinates text retrieval for QuickEdit.
//

import Foundation
import AppKit
import Defaults

enum TextRetrievalError: LocalizedError {
    case noTextAvailable
    case clipboardEmpty

    var errorDescription: String? {
        switch self {
        case .noTextAvailable:
            return "No text is selected"
        case .clipboardEmpty:
            return "Could not retrieve selected text. Please re-select the text and try again."
        }
    }
}

@MainActor
final class QuickEditFlowService {

    static let shared = QuickEditFlowService()

    private init() {}

    // MARK: - Public API

    var isNonAccessibilityMode: Bool {
        return Defaults[.quickEditConfig].enableNonAccessibilityTrigger
    }

    /// Retrieves the selected text from state, or via clipboard for non-accessibility mode
    func retrieveSelectedText(from state: QuickEditState) async throws -> String {
        // Text should already be in state for accessibility mode
        if let text = state.selectedText, !text.isEmpty {
            return text
        }

        // For non-accessibility mode, copy text via Cmd+C now (deferred from hint display time)
        if isNonAccessibilityMode {
            return try await retrieveViaClipboard(appName: state.currentAppName)
        }

        throw TextRetrievalError.noTextAvailable
    }

    // MARK: - Private Methods

    private func retrieveViaClipboard(appName: String?) async throws -> String {
        var targetPid: pid_t?

        if let appName = appName {
            targetPid = NSWorkspace.shared.runningApplications
                .first(where: { $0.localizedName == appName })?
                .processIdentifier
        }

        guard let text = await PasteboardManager.shared.copySelectedText(targetPid: targetPid),
              !text.isEmpty else {
            throw TextRetrievalError.clipboardEmpty
        }

        return text
    }
}
