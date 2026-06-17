//
//  QuickEditTriggerService.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import Combine
import CoreGraphics
import ApplicationServices
import AppKit
import Defaults

// MARK: - Delegate Protocol

/// Protocol for receiving QuickEdit trigger notifications
@MainActor
protocol QuickEditTriggerServiceDelegate: AnyObject {
    /// Called when QuickEdit should be triggered
    /// - Parameter request: The QuickEdit request with all necessary context
    func triggerQuickEdit(with request: QuickEditRequest)

    /// Called when QuickEdit should be closed (text deselected or cursor moved)
    func closeQuickEdit()
}

// MARK: - Trigger Service

@MainActor
class QuickEditTriggerService: NSObject {

    // MARK: - Properties

    weak var delegate: QuickEditTriggerServiceDelegate?

    private let highlightedTextManager = HighlightedTextManager.shared

    // Observers
    private var selectionCancellable: AnyCancellable?

    // Debounce task for selection processing
    private var selectionDebounceTask: Task<Void, Never>?

    // Smart positioning task (cancellable)
    private var smartPositioningTask: Task<Void, Never>?

    // Request ID to ignore stale positioning results
    private var currentPositioningRequestId: UUID?

    // Deduplication tracking
    private var lastProcessedText: String?
    private var lastProcessedTime: Date?
    private let deduplicationWindow: TimeInterval = 0.5 // 500ms

    // MARK: - Lifecycle

    func startListening() {
        setupSelectionTrigger()
    }

    func stopListening() {
        selectionDebounceTask?.cancel()
        selectionDebounceTask = nil
        smartPositioningTask?.cancel()
        smartPositioningTask = nil
        selectionCancellable?.cancel()
        selectionCancellable = nil
    }

    /// Cancels any pending text selection debounce task and smart positioning task
    /// Called when hint needs to be hidden immediately (scroll, keystroke, etc.)
    func cancelPendingSelection() {
        selectionDebounceTask?.cancel()
        smartPositioningTask?.cancel()
        selectionDebounceTask = nil
    }

    // MARK: - Selection Trigger

    private func setupSelectionTrigger() {
        // Observe selected text changes from HighlightedTextManager
        selectionCancellable = highlightedTextManager.$selectedText
            .sink { [weak self] selectedText in
                guard let self = self else { return }

                let textPreview = selectedText?.prefix(30) ?? "nil"
                print("[QuickEditTrigger] selectedText changed: '\(textPreview)' (length: \(selectedText?.count ?? 0))")

                self.selectionDebounceTask?.cancel()
                self.selectionDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)

                    guard !Task.isCancelled else {
                        print("[QuickEditTrigger] Debounce task cancelled")
                        return
                    }

                    print("[QuickEditTrigger] Debounce completed, handling selection")
                    self.handleTextSelection(selectedText)
                }
            }
    }

    private func handleTextSelection(_ selectedText: String?) {
        // If no text selected, notify delegate to close QuickEdit
        guard let text = selectedText, !text.isEmpty else {
            print("[QuickEditTrigger] handleTextSelection: empty/nil, closing QuickEdit")
            lastProcessedText = nil
            lastProcessedTime = nil
            delegate?.closeQuickEdit()
            return
        }

        // Check for duplicate within deduplication window
        let now = Date()
        if let lastText = lastProcessedText,
           let lastTime = lastProcessedTime,
           lastText == text,
           now.timeIntervalSince(lastTime) < deduplicationWindow {
            print("[QuickEditTrigger] handleTextSelection: DUPLICATE ignored (same text within \(deduplicationWindow)s)")
            return
        }

        // Update deduplication tracking
        lastProcessedText = text
        lastProcessedTime = now

        print("[QuickEditTrigger] handleTextSelection: '\(text.prefix(30))' (length: \(text.count))")

        // Get element and check if editable
        guard let element = highlightedTextManager.selectedTextElement else {
            return
        }

        // Get bounds using fallback hierarchy
        let bounds = getBoundsForElement(element)

        // Always use accessibility-based positioning
        handleAccessibilityBasedTrigger(
            text: text,
            element: element,
            bounds: bounds
        )
    }

    private func getBoundsForElement(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        if let positionValue = positionValue {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }

        if let sizeValue = sizeValue {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    private func calculateDisplayArea(textFrame: CGRect) -> CGRect {
        // UI dimensions
        let uiWidth = QuickEditConstants.maxWindowWidth
        let maxExpandedHeight = QuickEditConstants.maxWindowHeight
        let padding = QuickEditConstants.windowPadding

        // Get screen bounds
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(textFrame.origin) }) ?? NSScreen.main else {
            // Fallback: display below text, frame starts at text bottom and extends down
            return CGRect(
                x: textFrame.minX,
                y: textFrame.minY - maxExpandedHeight - padding,
                width: uiWidth,
                height: maxExpandedHeight
            )
        }

        let screenFrame = screen.visibleFrame

        // Check if there's enough space below the text (preferred)
        let spaceBelow = textFrame.minY - screenFrame.minY
        let spaceAbove = screenFrame.maxY - textFrame.maxY

        // Use max expanded height to ensure enough space when user activates
        if spaceBelow >= maxExpandedHeight + padding {
            // Display below text (isDisplayedBelowHighlightedText=true)
            // In macOS coords: text bottom = textFrame.minY
            // Frame should have its TOP (maxY) just below the text
            // frame.maxY = textFrame.minY - padding
            // frame.minY = frame.maxY - height
            let frameMaxY = textFrame.minY - padding
            return CGRect(
                x: textFrame.minX,
                y: frameMaxY - maxExpandedHeight,
                width: uiWidth,
                height: maxExpandedHeight
            )
        } else if spaceAbove >= maxExpandedHeight + padding {
            // Display above text (isDisplayedBelowHighlightedText=false)
            // In macOS coords: text top = textFrame.maxY
            // Frame should have its BOTTOM (minY) just above the text
            // frame.minY = textFrame.maxY + padding
            return CGRect(
                x: textFrame.minX,
                y: textFrame.maxY + padding,
                width: uiWidth,
                height: maxExpandedHeight
            )
        } else {
            // Not enough space either side, use available space
            let useHeight = min(maxExpandedHeight, max(spaceBelow, spaceAbove) - padding * 2)

            if spaceBelow >= spaceAbove {
                // Display below with available height
                let frameMaxY = textFrame.minY - padding
                return CGRect(
                    x: textFrame.minX,
                    y: frameMaxY - useHeight,
                    width: uiWidth,
                    height: useHeight
                )
            } else {
                // Display above with available height
                return CGRect(
                    x: textFrame.minX,
                    y: textFrame.maxY + padding,
                    width: uiWidth,
                    height: useHeight
                )
            }
        }
    }

    private func handleAccessibilityBasedTrigger(
        text: String,
        element: AXUIElement,
        bounds: CGRect?
    ) {
        // Try to get frame from multiple sources
        var textBounds: CGRect?

        // Priority 1: Selected text bound (if valid)
        if let selectedBounds = element.selectedTextBound(),
           selectedBounds.width > 0 && selectedBounds.height > 0 {
            // Convert from Cocoa coordinates to macOS screen coordinates
            textBounds = selectedBounds.toMacOSCoordinates()
        }
        // Priority 2: Highlighted text extractor (commented out - using mouse fallback instead)
//        else if let extractorResult = HighlightedTextBoundsExtractor.shared.getLastResult() {
//            let originalFrame = extractorResult.highlightedTextFrame
//            textBounds = originalFrame.toMacOSCoordinates()
//        }
        // Priority 3: Mouse location fallback - accurate since user likely just selected text with mouse
        if textBounds == nil {
            let mouseLocation = NSEvent.mouseLocation
            // mouseLocation is already in macOS screen coordinates (origin bottom-left)
            let rectSize: CGFloat = 20
            textBounds = CGRect(
                x: mouseLocation.x - rectSize / 2,
                y: mouseLocation.y - rectSize / 2,
                width: rectSize,
                height: rectSize
            )
        }

        guard let textFrame = textBounds else {
            return
        }

        // Get application name
        let applicationName = NSWorkspace.shared.frontmostApplication?.localizedName

        // Cancel any in-flight smart positioning task
        smartPositioningTask?.cancel()

        // Generate a unique request ID to track this request
        let requestId = UUID()
        currentPositioningRequestId = requestId

        // Use smart positioning asynchronously in a cancellable task
        smartPositioningTask = Task { @MainActor in
            print("[QuickEditTrigger] Starting smart positioning task (requestId: \(requestId))")

            let positioningResult = await calculateSmartDisplayArea(textFrame: textFrame)

            // Check if this request is still current (not superseded by a newer request)
            guard requestId == self.currentPositioningRequestId else {
                print("[QuickEditTrigger] Smart positioning task ignored - stale request (requestId: \(requestId))")
                return
            }

            // Create request
            let request = QuickEditRequest(
                applicationName: applicationName,
                textBefore: nil,
                selectedText: text,
                selectedTextBounds: textFrame,
                displayArea: positioningResult.displayArea,
                isDisplayedBelowHighlightedText: positioningResult.isBelow,
                cursorTextFrame: textFrame,
                smartHintPosition: positioningResult.smartHintPosition
            )

            // Notify delegate
            self.delegate?.triggerQuickEdit(with: request)
            print("[QuickEditTrigger] Smart positioning task completed successfully (requestId: \(requestId))")
        }
    }

    // MARK: - Smart Positioning

    /// Result of display area calculation
    private struct DisplayAreaResult {
        let displayArea: CGRect
        let isBelow: Bool
        let useSmartPositioning: Bool
        let smartHintPosition: CGRect?
    }

    /// Calculates display area using GPU-based smart positioning when enabled
    private func calculateSmartDisplayArea(textFrame: CGRect) async -> DisplayAreaResult {
        // Check if smart positioning is enabled (can be controlled via Defaults)
        let useSmartPositioning = Defaults[.quickEditSmartPositioning]

        if useSmartPositioning {
            // Use SmartUIPositioner for GPU-based optimal position finding
            // Search for hint-sized empty space near the text selection
            let config = UIPositioningConfig(
                uiSize: CGSize(
                    width: QuickEditConstants.hintWidth,
                    height: QuickEditConstants.hintHeight
                ),
                searchPaddingX: QuickEditConstants.hintSearchPaddingX,
                searchPaddingY: QuickEditConstants.hintSearchPaddingY,
                useComplexityAnalysis: true,
                horizontalBias: 0.05,
                proximityBias: 0.1,
                hintPadding: QuickEditConstants.hintPadding
            )

            if let result = await SmartUIPositioner.shared.findOptimalPosition(
                anchorPoint: textFrame.origin,
                anchorBounds: textFrame,
                config: config
            ) {
                // The result gives us the exact hint position - use it directly
                let hintPosition = result.displayArea

                // Calculate fullDisplayArea for the main window (when expanded)
                // This also returns the actual isBelow value after clamping to screen bounds
                let fullDisplayResult = calculateFullDisplayArea(
                    hintPosition: hintPosition,
                    textFrame: textFrame,
                    isDisplayedBelowAnchor: result.isDisplayedBelowAnchor
                )
                
                return DisplayAreaResult(
                    displayArea: fullDisplayResult.displayArea,
                    isBelow: fullDisplayResult.isBelow,
                    useSmartPositioning: true,
                    smartHintPosition: hintPosition
                )
            }
        }

        // Fallback to simple positioning
        let displayArea = calculateDisplayArea(textFrame: textFrame)
        let isDisplayedBelowHighlightedText = displayArea.maxY < textFrame.minY
        return DisplayAreaResult(
            displayArea: displayArea,
            isBelow: isDisplayedBelowHighlightedText,
            useSmartPositioning: false,
            smartHintPosition: nil
        )
    }

    /// Result of full display area calculation
    private struct FullDisplayAreaResult {
        let displayArea: CGRect
        let isBelow: Bool
    }

    /// Calculates the full window display area based on hint position
    /// The expanded area always shares either the top or bottom edge with the hint position.
    /// Returns both the display area and isBelow (true if hint is at top edge, false if at bottom edge)
    private func calculateFullDisplayArea(
        hintPosition: CGRect,
        textFrame: CGRect,
        isDisplayedBelowAnchor: Bool
    ) -> FullDisplayAreaResult {
        let fullWidth = QuickEditConstants.maxWindowWidth
        let fullHeight = QuickEditConstants.maxWindowHeight

        // IsBelow means top gravity.
        
        // Get the screen containing the hint
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(hintPosition.origin) }) ?? NSScreen.main else {
            // Fallback: just use hint position without screen bounds checking
            let x = hintPosition.minX
            let y = hintPosition.minY
            return FullDisplayAreaResult(
                displayArea: CGRect(x: x, y: y, width: fullWidth, height: fullHeight),
                isBelow: false
            )
        }

        let visibleFrame = screen.visibleFrame

        // Clamp X position to keep window on screen horizontally
        var x = hintPosition.minX
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - fullWidth
        x = max(minX, min(x, maxX))

        var finalIsBelow: Bool
        var finalDisplayArea: CGRect

        if isDisplayedBelowAnchor {
            // Display area's maxY aligns with hint's maxY
            let hasRoomBelow = hintPosition.maxY - fullHeight >= visibleFrame.minY
            if hasRoomBelow {
                finalDisplayArea = CGRect(x: x, y: hintPosition.maxY - fullHeight, width: fullWidth, height: fullHeight)
                finalIsBelow = false
            } else {
                finalDisplayArea = CGRect(x: x, y: hintPosition.minY, width: fullWidth, height: fullHeight)
                finalIsBelow = true
            }
        } else {
            let hasRoomAbove = hintPosition.minY + fullHeight <= visibleFrame.maxY
            if hasRoomAbove {
                finalDisplayArea = CGRect(x: x, y: hintPosition.minY, width: fullWidth, height: fullHeight)
                finalIsBelow = true
            } else {
                finalDisplayArea = CGRect(x: x, y: hintPosition.maxY - fullHeight, width: fullWidth, height: fullHeight)
                finalIsBelow = false
            }
        }

        return FullDisplayAreaResult(
            displayArea: finalDisplayArea,
            isBelow: finalIsBelow
        )
    }
}
