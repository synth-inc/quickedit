//
//  QuickEditPromptListWindowController.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import AppKit
import SwiftUI

@MainActor
class QuickEditPromptListWindowController: NSObject, NSWindowDelegate {
    // MARK: - Singleton

    static let shared = QuickEditPromptListWindowController()

    // MARK: - Private Variables

    private var window: NonActivatingPanel?
    private var hostingController: NSHostingController<AnyView>?

    // MARK: - Public Variables

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - Public Functions

    func show(
        anchoredTo hintFrame: CGRect,
        currentAppBundleID: String?,
        onPromptSelected: @escaping (CustomPrompt) -> Void,
        onEditPrompt: @escaping (CustomPrompt) -> Void,
        onDeletePrompt: @escaping (CustomPrompt) -> Void,
        onHover: @escaping (Bool) -> Void
    ) {
        let content = QuickEditHintPromptListView(
            currentAppBundleID: currentAppBundleID,
            onPromptSelected: { prompt in
                self.hide()
                onPromptSelected(prompt)
            },
            onEditPrompt: { prompt in
                self.hide()
                onEditPrompt(prompt)
            },
            onDeletePrompt: { prompt in
                self.hide()
                onDeletePrompt(prompt)
            }
        )
        .onHover { hovering in
            onHover(hovering)
        }

        if window != nil {
            hostingController?.rootView = AnyView(content)
            updatePosition(anchoredTo: hintFrame)
            window?.orderFront(nil)
            return
        }

        createWindow(content: AnyView(content), anchoredTo: hintFrame)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingController = nil
    }

    func updatePosition(anchoredTo hintFrame: CGRect) {
        guard let window = window,
              let hostingView = window.contentViewController?.view
        else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()

        var contentSize = hostingView.fittingSize
        if contentSize.width <= 0 || contentSize.height <= 0 {
            contentSize = CGSize(width: 200, height: 100)
        }

        window.setContentSize(contentSize)

        // Position below the hint with a small gap
        let frame = CGRect(
            origin: CGPoint(
                x: hintFrame.minX,
                y: hintFrame.minY - contentSize.height - 4
            ),
            size: contentSize
        )

        window.setFrame(frame, display: false)
    }

    // MARK: - Private Functions

    private func createWindow(content: AnyView, anchoredTo hintFrame: CGRect) {
        let hostingController = NSHostingController(rootView: content)
        self.hostingController = hostingController

        window = NonActivatingPanel(contentViewController: hostingController)

        guard let window = window else { return }

        window.setup(delegate: self, addShadow: false)

        updatePosition(anchoredTo: hintFrame)

        window.alphaValue = 0.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1.0
        }
    }
}
