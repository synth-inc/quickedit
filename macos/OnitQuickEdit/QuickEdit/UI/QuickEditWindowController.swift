//
//  QuickEditWindowController.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import AppKit
import SwiftUI

class QuickEditWindowController: NSWindowController {

    // MARK: - Properties

    private let state: QuickEditState

    // MARK: - Initialization

    init(state: QuickEditState) {
        self.state = state

        // Create EditablePanel with fixed size
        let panel = EditablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: QuickEditConstants.maxWindowWidth,
                height: QuickEditConstants.maxWindowHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        // Disable shadow on macOS 26+ as glassEffect provides its own visual treatment
        if #available(macOS 26.0, *) {
            panel.hasShadow = false
        } else {
            panel.hasShadow = true
        }
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        // Create SwiftUI view
        let contentView = QuickEditView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        panel.contentView = hostingView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Positioning

    /// Positions the window in the specified display area
    /// - Parameter displayArea: The CGRect where the window should appear
    func positionInDisplayArea(_ displayArea: CGRect) {
        guard let window = window else { return }

        let finalFrame: CGRect
        if state.isDisplayedBelowHighlightedText {
            // Position below cursor/text - align to top of displayArea
            finalFrame = CGRect(
                x: displayArea.minX,
                y: displayArea.maxY - QuickEditConstants.maxWindowHeight,
                width: QuickEditConstants.maxWindowWidth,
                height: QuickEditConstants.maxWindowHeight
            )
        } else {
            // Position above cursor/text - align to bottom of displayArea
            finalFrame = CGRect(
                x: displayArea.minX,
                y: displayArea.minY,
                width: QuickEditConstants.maxWindowWidth,
                height: QuickEditConstants.maxWindowHeight
            )
        }

        window.setFrame(finalFrame, display: true, animate: false)
    }

    // MARK: - Focus Management

    /// Makes the window key so it can receive keyboard input
    func makeWindowEditable() {
        guard let window = window else {
            return
        }

        // Make the window key and order it front
        // Note: We don't call NSApp.activate() here because that would bring
        // ALL app windows to the front (including Settings). The floating panel
        // can become key without activating the entire app.
        window.makeKey()
    }
}
