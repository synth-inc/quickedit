//
//  SelectionHintWindowController.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import AppKit
import SwiftUI

/// Window controller for the selection hint with context-aware buttons
@MainActor
class SelectionHintWindowController: NSObject, NSWindowDelegate, ObservableObject {

    // MARK: - Singleton

    static let shared = SelectionHintWindowController()

    // MARK: - Private Properties

    private var hostingController: NSHostingController<SelectionHintView>?
    private let viewModel = SelectionHintViewModel()

    /// The hint window (accessible for click-outside detection)
    private(set) var window: ToggleableKeyPanel?

    // MARK: - Public Properties

    /// Whether the hint is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// Whether the mouse is currently over the popup window
    var isMouseInPopup: Bool {
        guard let window = window, window.isVisible else { return false }
        
        let mouseLocation = NSEvent.mouseLocation
        let expandedFrame = window.frame.insetBy(dx: -10, dy: -10)
        
        return expandedFrame.contains(mouseLocation)
    }

    /// The selected range that this hint is associated with
    private(set) var associatedRange: NSRange?

    /// Last position where the hint was shown (for re-showing after actions)
    private(set) var lastPosition: CGPoint?

    // MARK: - Callbacks

    var onFreeze: (() -> Void)?
    var onUnfreeze: (() -> Void)?
    var onUnfreezeAll: (() -> Void)?
    var onRetry: (() -> Void)?
    var onAIEdit: ((String) -> Void)?
    var onVersionNavigate: ((Int) -> Void)?
    var onDismissedByClickOutside: (() -> Void)?
    var onDiffUndoHoverExit: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupViewModel()
    }

    // MARK: - Public Methods

    /// Show the hint at the specified position with context
    /// - Parameters:
    ///   - position: Screen position to show the hint
    ///   - range: The text range this hint is associated with
    ///   - context: The context determining which buttons to show
    ///   - versionInfo: Optional version info (current, total) for pagination
    ///   - showUnfreezeAll: Whether to show "Un-freeze all" button (when multiple frozen segments)
    func show(
        at position: CGPoint,
        for range: NSRange,
        context: SelectionHintContext,
        versionInfo: (current: Int, total: Int)? = nil,
        showUnfreezeAll: Bool = false
    ) {
        associatedRange = range
        lastPosition = position
        viewModel.context = context
        viewModel.versionInfo = versionInfo
        viewModel.showUnfreezeAll = showUnfreezeAll
        viewModel.mode = .actions
        viewModel.aiEditText = ""

        if window != nil {
            updateWindowPosition(to: position)
            window?.orderFrontRegardless()
            window?.disableKeyStatus()
            return
        }

        createWindow(at: position)
    }

    /// Hide the hint
    func hide() {
        MouseNotificationManager.shared.removeDelegate(self)

        // Capture references before clearing
        let windowToHide = window
        let hostingToRelease = hostingController

        window = nil
        hostingController = nil
        associatedRange = nil
        viewModel.reset()

        // Order out the window and defer hostingController release to avoid SwiftUI layout crashes
        windowToHide?.orderOut(nil)
        if hostingToRelease != nil {
            DispatchQueue.main.async {
                // hostingController is released here after the current layout cycle
                _ = hostingToRelease
            }
        }
    }

    /// Update the context (e.g., after freeze/unfreeze)
    func updateContext(_ context: SelectionHintContext, showUnfreezeAll: Bool = false) {
        viewModel.updateContext(context, showUnfreezeAll: showUnfreezeAll)

        // Refresh window size since buttons changed
        if let window = window {
            updateWindowPosition(to: CGPoint(
                x: window.frame.midX,
                y: window.frame.minY - 4
            ))
        }
    }

    /// Update the version info displayed in the hint
    func updateVersionInfo(_ info: (current: Int, total: Int)?) {
        viewModel.versionInfo = info
    }

    /// Update the associated range (after version navigation changes the segment range)
    func updateAssociatedRange(_ range: NSRange) {
        associatedRange = range
    }

    /// Switch to AI-Edit mode
    func showAIEditMode() {
        viewModel.mode = .aiEdit
        // Enable key status so the text field can receive focus
        window?.enableKeyStatus()
    }

    /// Switch back to actions mode
    func showActionsMode() {
        viewModel.mode = .actions
        viewModel.aiEditText = ""
        // Disable key status to let keyboard events pass through to QuickEdit
        window?.disableKeyStatus()
    }

    /// Show diff undo hint at the specified position
    /// - Parameters:
    ///   - position: Screen position to show the hint
    ///   - segment: The diff segment to undo
    ///   - onUndo: Callback when undo is clicked
    func showDiffUndo(at position: CGPoint, for segment: DiffSegment, onUndo: @escaping () -> Void) {
        associatedRange = segment.range
        lastPosition = position
        viewModel.mode = .diffUndo
        viewModel.onDiffUndo = onUndo

        if window != nil {
            updateWindowPosition(to: position)
            window?.orderFrontRegardless()
            window?.disableKeyStatus()
            return
        }

        createWindow(at: position)
    }

    // MARK: - Private Methods

    private func setupViewModel() {
        viewModel.configure(
            context: .standard,
            versionInfo: nil,
            showUnfreezeAll: false,
            onFreeze: { [weak self] in
                self?.onFreeze?()
            },
            onUnfreeze: { [weak self] in
                self?.onUnfreeze?()
            },
            onUnfreezeAll: { [weak self] in
                self?.onUnfreezeAll?()
            },
            onRetry: { [weak self] in
                self?.onRetry?()
            },
            onAIEdit: { [weak self] instruction in
                self?.onAIEdit?(instruction)
            },
            onVersionNavigate: { [weak self] index in
                self?.onVersionNavigate?(index)
            },
            onDismiss: { [weak self] in
                self?.hide()
            },
            onAIEditModeEnter: { [weak self] in
                // Enable key status so the text field can receive focus
                self?.window?.enableKeyStatus()
            }
        )

        viewModel.onDiffUndoHoverExit = { [weak self] in
            self?.onDiffUndoHoverExit?()
        }
    }

    private func createWindow(at position: CGPoint) {
        let hostingController = NSHostingController(
            rootView: SelectionHintView(viewModel: viewModel)
        )
        self.hostingController = hostingController

        // Use ToggleableKeyPanel which doesn't accept key by default
        let panel = ToggleableKeyPanel(contentViewController: hostingController)
        panel.setup(delegate: self)

        self.window = panel

        updateWindowPosition(to: position)

        // Fade in animation
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        // Register for click outside detection
        MouseNotificationManager.shared.addDelegate(self)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1.0
        }
    }

    private func updateWindowPosition(to position: CGPoint) {
        guard let window = window,
              let hostingView = window.contentViewController?.view else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()

        var contentSize = hostingView.fittingSize
        if contentSize.width <= 0 || contentSize.height <= 0 {
            contentSize = CGSize(width: 280, height: 32)
        }

        window.setContentSize(contentSize)

        // Position the hint centered horizontally on the position, above the selection
        let frame = CGRect(
            origin: CGPoint(
                x: position.x - contentSize.width / 2,
                y: position.y + 4
            ),
            size: contentSize
        )

        // Ensure the window stays within QuickEdit window bounds horizontally, and on screen
        let quickEditWindow = QuickEditManager.shared.windowService.windowController?.window
        
        window.setFrame(frame.adjustedToFitWindow(quickEditWindow), display: false)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // When the hint loses key status (in AI-Edit mode), hide it and clear selection
        hide()
        onDismissedByClickOutside?()
    }
}

// MARK: - MouseNotificationDelegate

extension SelectionHintWindowController: MouseNotificationDelegate {
    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveSingleClick event: NSEvent) {
        guard let window = window, window.isVisible else { return }

        let clickLocation = NSEvent.mouseLocation

        // Check if click is inside the hint window
        if window.frame.contains(clickLocation) {
            return
        }

        // Check if click is inside the QuickEdit main window (let SelectableTextView handle it)
        if let quickEditWindow = QuickEditManager.shared.windowService.windowController?.window,
           quickEditWindow.frame.contains(clickLocation) {
            return
        }

        // Click is outside all relevant windows - hide hint and clear selection
        hide()
        onDismissedByClickOutside?()
    }
}
