//
//  QuickEditDisplayService.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import AppKit
import KeyboardShortcuts

@MainActor
class QuickEditDisplayService {

    // MARK: - Properties

    private let windowService: QuickEditWindowService
    private let state: QuickEditState

    // MARK: - Initialization

    init(windowService: QuickEditWindowService, state: QuickEditState) {
        self.windowService = windowService
        self.state = state
    }

    // MARK: - Display Control

    /// Shows the QuickEdit UI in the specified display area
    /// - Parameter displayArea: The CGRect where the UI should appear
    func showQuickEdit(in displayArea: CGRect) {
        // Update state
        state.isVisible = true
        state.displayArea = displayArea

        // Create window if needed
        windowService.createWindow(state: state)

        // Position and show
        windowService.positionWindow(in: displayArea)
        windowService.showWindow()
    }

    /// Hides the QuickEdit UI
    func hideQuickEdit() {
        // Update state
        state.isVisible = false

        // Hide window
        windowService.hideWindow()

        // Reset state
        state.reset()
    }
}
