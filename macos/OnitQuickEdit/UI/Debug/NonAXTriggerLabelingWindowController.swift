//
//  NonAXTriggerLabelingWindowController.swift
//  Onit
//
//  Window controller for the non-accessibility trigger labeling interface.
//

#if DEBUG || ONIT_BETA
import AppKit
import SwiftUI

@MainActor
final class NonAXTriggerLabelingWindowController: NSObject, NSWindowDelegate {
    // MARK: - Singleton

    static let shared = NonAXTriggerLabelingWindowController()

    // MARK: - Properties

    private var window: CenteredWindow<NonAXTriggerLabelingView>?

    // MARK: - Public Functions

    func show(capture: NonAXTriggerDebugCapture) {
        // Close existing window if any
        if let existingWindow = window {
            existingWindow.close()
            window = nil
        }

        let labelingView = NonAXTriggerLabelingView(capture: capture) { [weak self] in
            self?.closeWindow()
        }

        let newWindow = CenteredWindow(
            rootView: labelingView,
            windowLevel: .floating,
            hideTitleBar: false,
            canResize: true,
            canDrag: true,
            canCloseWithEsc: true,
            windowSize: (width: 800, height: 700)
        )

        newWindow.delegate = self
        newWindow.title = "Non-AX Trigger Test Case Labeling"
        newWindow.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)

        window = newWindow
    }

    func closeWindow() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else {
            return
        }

        window?.cleanupObservers()
        window?.delegate = nil
        window = nil
    }
}
#endif
