//
//  FalseNegativeReportButton.swift
//  Onit
//
//  Debug-only floating button that appears near the mouse when non-AX trigger
//  detection rejects regions. Clicking opens the labeling UI for the test case.
//

#if DEBUG || ONIT_BETA
import Defaults
import SwiftUI

struct FalseNegativeReportButtonView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text("😱")
                    .font(.system(size: 14))
                Text("is text highlighted?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        .background(.ultraThinMaterial)
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

@MainActor
final class FalseNegativeReportButtonPresenter {
    static let shared = FalseNegativeReportButtonPresenter()

    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?
    private var pendingCapture: NonAXTriggerDebugCapture?

    /// Size of the button view (approximate, will be measured)
    private let buttonSize = CGSize(width: 130, height: 24)

    func show(near mouseLocation: CGPoint, capture: NonAXTriggerDebugCapture) {
        guard !Defaults[.hideBugReportEmoji] else { return }

        // Cancel any existing dismiss task
        dismissTask?.cancel()

        // Store capture for when button is clicked
        pendingCapture = capture

        // Close existing window if any
        if let window {
            window.orderOut(nil)
            self.window = nil
        }

        // Calculate anchor bounds from changed regions
        // Convert from image coordinates (pixels) to screen coordinates (points)
        let anchorBounds: CGRect? = {
            guard !capture.changedRegions.isEmpty else { return nil }

            // Get window frame for coordinate conversion
            guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
                  let mainWindow = pid.firstMainWindow,
                  let windowFrame = mainWindow.getFrame(convertedToGlobalCoordinateSpace: true) else {
                return nil
            }

            // Union all changed regions
            var bounds = capture.changedRegions[0]
            for region in capture.changedRegions.dropFirst() {
                bounds = bounds.union(region)
            }

            // Convert from image pixels to screen points
            let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
            return CGRect(
                x: windowFrame.minX + bounds.minX / scaleFactor,
                y: windowFrame.minY + bounds.minY / scaleFactor,
                width: bounds.width / scaleFactor,
                height: bounds.height / scaleFactor
            )
        }()

        // Use SmartUIPositioner for placement
        Task { @MainActor in
            let config = UIPositioningConfig(
                uiSize: buttonSize,
                searchPaddingX: 100,
                searchPaddingY: 50,
                useComplexityAnalysis: true,
                horizontalBias: 0.05,
                proximityBias: 0.1,
                hintPadding: 4
            )

            let position: CGPoint
            if let result = await SmartUIPositioner.shared.findOptimalPosition(
                anchorPoint: mouseLocation,
                anchorBounds: anchorBounds,
                config: config
            ) {
                position = result.displayArea.origin
            } else {
                // Fallback: position near mouse
                position = CGPoint(x: mouseLocation.x + 20, y: mouseLocation.y - buttonSize.height / 2)
            }

            self.showWindow(at: position)
        }
    }

    private func showWindow(at position: CGPoint) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: buttonSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = false
        window.hasShadow = false

        let hostingView = NSHostingView(rootView: FalseNegativeReportButtonView(onTap: { [weak self] in
            self?.handleTap()
        }))
        hostingView.frame = NSRect(origin: .zero, size: buttonSize)
        window.contentView = hostingView

        window.setFrameOrigin(position)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        // Auto-dismiss after 5 seconds
        dismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                self.dismiss()
            } catch {
                // Cancelled
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        window?.orderOut(nil)
        window = nil
        pendingCapture = nil
    }

    /// Dismisses the button only if the given screen location is outside the button window.
    /// Use this for global click handlers to avoid dismissing when clicking on the button itself.
    func dismissIfClickOutside(at screenLocation: CGPoint) {
        guard let window = window else { return }
        if !window.frame.contains(screenLocation) {
            dismiss()
        }
    }

    private func handleTap() {
        guard let capture = pendingCapture else {
            dismiss()
            return
        }

        // Dismiss the button first
        dismiss()

        // Open the labeling UI with the captured data
        NonAXTriggerLabelingWindowController.shared.show(capture: capture)
    }
}
#endif
