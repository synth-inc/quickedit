//
//  QuickEditHintWindowController.swift
//  Onit
//
//  Created by Loyd Kim on 11/21/25.
//

/*
 THE ANCHORING LOGIC IN THIS CLASS IS JUST A PLACEHOLDER AND REQUIRES A ROBUSTNESS UPDATE.
 REQUIRED UPDATES MAY BE INTEGRATED WITH TIM'S DETECTION ALGO
 */

import AppKit
import SwiftUI

@MainActor
class QuickEditHintWindowController: NSObject, NSWindowDelegate, ObservableObject {
    // MARK: - Private Variables

    private var hostingController: NSHostingController<QuickEditHintView>? = nil

    // MARK: - Public Variables

    /// The hint window (accessible for click-outside detection)
    private(set) var window: NonActivatingPanel? = nil

    var isVisible: Bool {
        return window?.isVisible ?? false
    }

    /// Whether the hint is displayed below the highlighted text (true) or above (false)
    private(set) var isDisplayedBelowHighlightedText: Bool = true

    /// The current frame of the hint window in screen coordinates
    var currentFrame: CGRect? {
        window?.frame
    }

    // MARK: - Public Functions

    func show(at position: CGPoint, displayArea: CGRect, smartHintPosition: CGRect? = nil) {
        if window != nil {
            updateWindow(at: position, displayArea: displayArea, smartHintPosition: smartHintPosition)
            window?.orderFront(nil)
            return
        }

        createWindow(at: position, displayArea: displayArea, smartHintPosition: smartHintPosition)

        // Track hint shown
        AnalyticsManager.QuickEdit.hintShown()
    }

    func hide() {
        // Also hide the prompt list dropdown if visible
        QuickEditPromptListWindowController.shared.hide()

        window?.orderOut(nil)
        window = nil
        hostingController = nil
    }

    // MARK: - Private Functions

    private func createWindow(at position: CGPoint, displayArea: CGRect, smartHintPosition: CGRect?) {
        let hostingController = NSHostingController(
            rootView: QuickEditHintView()
        )
        self.hostingController = hostingController

        window = NonActivatingPanel(
            contentViewController: hostingController
        )

        guard let window = window else { return }

        window.setup(
            delegate: self,
            addShadow: false
        )

        updateWindow(at: position, displayArea: displayArea, smartHintPosition: smartHintPosition)

        window.alphaValue = 0.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }
    }

    private func updateWindow(at position: CGPoint, displayArea: CGRect, smartHintPosition: CGRect?) {
        if let hostingController = hostingController {
            hostingController.rootView = QuickEditHintView()
        }

        updateWindowAnchorPosition(
            anchorPosition: position,
            displayArea: displayArea,
            smartHintPosition: smartHintPosition
        )
    }

    private func updateWindowAnchorPosition(anchorPosition: CGPoint, displayArea: CGRect, smartHintPosition: CGRect?) {
        guard let window = window,
              let hostingView = window.contentViewController?.view
        else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()

        var contentSize = hostingView.fittingSize

        if contentSize.width <= 0 || contentSize.height <= 0 {
            contentSize = CGSize(width: QuickEditConstants.maxWindowWidth, height: 28)
        }

        window.setContentSize(contentSize)

        // If smart positioning provided an exact position, use it directly
        if let smartPosition = smartHintPosition {
            // Use the smart position directly - it's already calculated by the GPU
            isDisplayedBelowHighlightedText = (displayArea.maxY - smartPosition.maxY) < 2 // Some tolerance.

            let frame = CGRect(
                origin: smartPosition.origin,
                size: contentSize
            )

            window.setFrame(frame, display: false)
            return
        }

        // Fallback: calculate position based on displayArea (legacy behavior)
        // Determine if we're displaying below or above based on displayArea
        // In macOS coords: if displayArea is below anchorPosition, we're displaying below text
        isDisplayedBelowHighlightedText = displayArea.maxY < anchorPosition.y

        // Position hint aligned with displayArea edges
        let yPosition: CGFloat

        if isDisplayedBelowHighlightedText {
            // Main window is below text (displayArea is below)
            // Stick hint to TOP of displayArea (maxY - hint height)
            yPosition = displayArea.maxY - contentSize.height
        } else {
            // Main window is above text (displayArea is above)
            // Stick hint to BOTTOM of displayArea (minY)
            yPosition = displayArea.minY
        }

        let frame = CGRect(
            origin: CGPoint(
                x: displayArea.minX,
                y: yPosition
            ),
            size: contentSize
        )
        
        window.setFrame(frame, display: false)
    }
}
