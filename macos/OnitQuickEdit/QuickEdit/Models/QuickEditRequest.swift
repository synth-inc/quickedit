//
//  QuickEditRequest.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import CoreGraphics

/// Represents a complete QuickEdit request with all necessary context
struct QuickEditRequest {
    // MARK: - Context from Accessibility

    /// Name of the application where QuickEdit was triggered
    let applicationName: String?

    /// Text before the cursor position (from accessibility API)
    let textBefore: String?

    // MARK: - Context from Selection

    /// Text that was selected/highlighted by the user (from HighlightedTextManager)
    var selectedText: String?

    /// Bounds of the selected text on screen
    let selectedTextBounds: CGRect?

    // MARK: - Display Information

    /// Area where the QuickEdit UI should be displayed (calculated from accessibility bounds)
    let displayArea: CGRect

    /// Whether the UI should be displayed below the highlighted text (true) or above (false)
    let isDisplayedBelowHighlightedText: Bool

    /// Frame of the text cursor area for positioning reference
    let cursorTextFrame: CGRect

    /// The exact hint position when using smart positioning (nil when not using smart positioning)
    let smartHintPosition: CGRect?

    // MARK: - Initialization

    init(
        applicationName: String?,
        textBefore: String?,
        selectedText: String?,
        selectedTextBounds: CGRect?,
        displayArea: CGRect,
        isDisplayedBelowHighlightedText: Bool,
        cursorTextFrame: CGRect,
        smartHintPosition: CGRect? = nil
    ) {
        self.applicationName = applicationName
        self.textBefore = textBefore
        self.selectedText = selectedText
        self.selectedTextBounds = selectedTextBounds
        self.displayArea = displayArea
        self.isDisplayedBelowHighlightedText = isDisplayedBelowHighlightedText
        self.cursorTextFrame = cursorTextFrame
        self.smartHintPosition = smartHintPosition
    }
}
