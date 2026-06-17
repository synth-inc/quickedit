//
//  QuickEditWindowService.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import AppKit

@MainActor
class QuickEditWindowService {

    // MARK: - Properties

    var windowController: QuickEditWindowController?

    // MARK: - Window Lifecycle

    /// Creates the window controller if it doesn't exist
    /// - Parameter state: The QuickEditState to bind to the UI
    func createWindow(state: QuickEditState) {
        if windowController == nil {
            windowController = QuickEditWindowController(state: state)
        }
    }

    /// Shows the QuickEdit window
    func showWindow() {
        windowController?.showWindow(nil)
    }

    /// Hides the QuickEdit window
    func hideWindow() {
        windowController?.close()
    }

    /// Positions the window in the specified display area
    /// - Parameter displayArea: The CGRect where the window should be positioned
    func positionWindow(in displayArea: CGRect) {
        windowController?.positionInDisplayArea(displayArea)
    }

    /// Checks if the window is currently visible
    var isWindowVisible: Bool {
        return windowController?.window?.isVisible ?? false
    }

    /// Makes the window editable by allowing it to become key and making it key
    func makeWindowEditable() {
        windowController?.makeWindowEditable()
    }

    /// Enables or disables window dragging
    /// - Parameter enabled: true to enable dragging, false to disable
    func setDraggingEnabled(_ enabled: Bool) {
        guard let window = windowController?.window else { return }
        window.isMovable = enabled
        window.isMovableByWindowBackground = enabled
    }
}
