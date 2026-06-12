//
//  UnfreezeHintWindowController.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import AppKit
import SwiftUI

/// Window controller for the Un-freeze hint shown when clicking on frozen text
@MainActor
class UnfreezeHintWindowController: NSObject, NSWindowDelegate, ObservableObject {

    // MARK: - Singleton

    static let shared = UnfreezeHintWindowController()

    // MARK: - Private Properties

    private var hostingController: NSHostingController<UnfreezeHintView>?

    /// The hint window (accessible for click-outside detection)
    private(set) var window: NonActivatingPanel?

    // MARK: - Public Properties

    /// Whether the hint is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// The frozen range that this hint is associated with
    private(set) var associatedRange: NSRange?

    // MARK: - Callbacks

    var onUnfreeze: ((NSRange) -> Void)?
    var onUnfreezeAll: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Show the hint at the specified position
    /// - Parameters:
    ///   - position: Screen position to show the hint
    ///   - frozenRange: The frozen range this hint is associated with
    ///   - showUnfreezeAll: Whether to show the "Un-freeze all" button
    func show(at position: CGPoint, for frozenRange: NSRange, showUnfreezeAll: Bool) {
        associatedRange = frozenRange

        if window != nil {
            updateWindow(at: position, showUnfreezeAll: showUnfreezeAll)
            window?.orderFront(nil)
            return
        }

        createWindow(at: position, showUnfreezeAll: showUnfreezeAll)
    }

    /// Hide the hint
    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingController = nil
        associatedRange = nil
    }

    // MARK: - Private Methods

    private func createWindow(at position: CGPoint, showUnfreezeAll: Bool) {
        let view = UnfreezeHintView(
            showUnfreezeAll: showUnfreezeAll,
            onUnfreeze: { [weak self] in
                guard let self = self, let range = self.associatedRange else { return }
                self.onUnfreeze?(range)
                self.hide()
            },
            onUnfreezeAll: { [weak self] in
                self?.onUnfreezeAll?()
                self?.hide()
            }
        )

        let hostingController = NSHostingController(rootView: view)
        self.hostingController = hostingController

        let panel = NonActivatingPanel(contentViewController: hostingController)
        panel.setup(delegate: self, addShadow: false)

        self.window = panel

        updateWindowPosition(to: position)

        // Fade in animation
        panel.alphaValue = 0.0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1.0
        }
    }

    private func updateWindow(at position: CGPoint, showUnfreezeAll: Bool) {
        let view = UnfreezeHintView(
            showUnfreezeAll: showUnfreezeAll,
            onUnfreeze: { [weak self] in
                guard let self = self, let range = self.associatedRange else { return }
                self.onUnfreeze?(range)
                self.hide()
            },
            onUnfreezeAll: { [weak self] in
                self?.onUnfreezeAll?()
                self?.hide()
            }
        )

        hostingController?.rootView = view
        updateWindowPosition(to: position)
    }

    private func updateWindowPosition(to position: CGPoint) {
        guard let window = window,
              let hostingView = window.contentViewController?.view else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()

        var contentSize = hostingView.fittingSize
        if contentSize.width <= 0 || contentSize.height <= 0 {
            contentSize = CGSize(width: 180, height: 32)
        }

        window.setContentSize(contentSize)

        // Position the hint centered horizontally on the position, above the frozen text
        let frame = CGRect(
            origin: CGPoint(
                x: position.x - contentSize.width / 2,
                y: position.y + 4
            ),
            size: contentSize
        )

        // Ensure the window stays on screen
        window.setFrame(frame.adjustedToFitScreen(), display: false)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Don't hide when window loses key status
    }
}
