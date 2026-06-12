//
//  SelectableTextView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Constants

private enum SelectableTextViewConstants {
    static let frozenBackgroundColor = NSColor.frozenTextBackground
    static let modifiedBackgroundColor = NSColor(white: 0.4, alpha: 0.35)

    // Diff view colors
    static let diffInsertForegroundColor = NSColor.lime400
    static let diffDeleteForegroundColor = NSColor.redPale400
    
    static let diffInsertBackgroundColor = NSColor.lime400.withAlphaComponent(0.1)
    static let diffDeleteBackgroundColor = NSColor(white: 0.4, alpha: 0.35)
}

// MARK: - SelectableTextView

struct SelectableTextView: NSViewRepresentable {
    typealias NSViewType = SelectableTextContainerView

    @Binding var text: String

    let fontSize: CGFloat
    let lineHeight: CGFloat
    let isEditable: Bool
    let frozenRanges: [NSRange]
    let modifiedRanges: [NSRange]
    let regeneratingRanges: [NSRange]
    let textColor: NSColor
    let maxHeight: CGFloat?

    // Diff view properties
    let isDiffMode: Bool
    let diffSegments: [DiffSegment]

    var onSelectionChange: (([NSRange], SelectableNSTextView?) -> Void)?
    var onFrozenClick: ((NSRange, SelectableNSTextView?) -> Void)?
    var onModifiedClick: ((NSRange, SelectableNSTextView?) -> Void)?
    var onClickOutsideSelection: (() -> Void)?
    var onRegeneratingRectsChange: (([CGRect]) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    var onDiffSegmentHover: ((DiffSegment, SelectableNSTextView?) -> Void)?
    var onDiffSegmentUnhover: (() -> Void)?

    init(
        text: Binding<String>,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        isEditable: Bool,
        frozenRanges: [NSRange],
        modifiedRanges: [NSRange],
        regeneratingRanges: [NSRange],
        textColor: NSColor,
        maxHeight: CGFloat? = nil,
        isDiffMode: Bool = false,
        diffSegments: [DiffSegment] = [],
        onSelectionChange: (([NSRange], SelectableNSTextView?) -> Void)? = nil,
        onFrozenClick: ((NSRange, SelectableNSTextView?) -> Void)? = nil,
        onModifiedClick: ((NSRange, SelectableNSTextView?) -> Void)? = nil,
        onClickOutsideSelection: (() -> Void)? = nil,
        onRegeneratingRectsChange: (([CGRect]) -> Void)? = nil,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        onDiffSegmentHover: ((DiffSegment, SelectableNSTextView?) -> Void)? = nil,
        onDiffSegmentUnhover: (() -> Void)? = nil
    ) {
        self._text = text
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.isEditable = isEditable
        self.frozenRanges = frozenRanges
        self.modifiedRanges = modifiedRanges
        self.regeneratingRanges = regeneratingRanges
        self.textColor = textColor
        self.maxHeight = maxHeight
        self.isDiffMode = isDiffMode
        self.diffSegments = diffSegments
        self.onSelectionChange = onSelectionChange
        self.onFrozenClick = onFrozenClick
        self.onModifiedClick = onModifiedClick
        self.onClickOutsideSelection = onClickOutsideSelection
        self.onRegeneratingRectsChange = onRegeneratingRectsChange
        self.onHeightChange = onHeightChange
        self.onDiffSegmentHover = onDiffSegmentHover
        self.onDiffSegmentUnhover = onDiffSegmentUnhover
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Self.Context) -> SelectableTextContainerView {
        let containerView = SelectableTextContainerView(maxHeight: maxHeight)
        let textView = SelectableNSTextView()

        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

        let coordinator = context.coordinator
        textView.onSelectionChange = { coordinator.handleSelectionChange($0) }
        textView.onFrozenClick = { coordinator.handleFrozenClick($0) }
        textView.onModifiedClick = { coordinator.handleModifiedClick($0) }
        textView.onClickOutsideSelection = { coordinator.handleClickOutsideSelection() }
        textView.onRegeneratingRectsChange = { coordinator.handleRegeneratingRectsChange($0) }
        textView.onDiffSegmentHover = { coordinator.handleDiffSegmentHover($0) }
        textView.onDiffSegmentUnhover = { coordinator.handleDiffSegmentUnhover() }

        containerView.configure(with: textView)
        containerView.onHeightChange = { coordinator.handleHeightChange($0) }
        coordinator.textView = textView
        coordinator.containerView = containerView

        return containerView
    }

    func updateNSView(_ containerView: SelectableTextContainerView, context: Self.Context) {
        guard let textView = containerView.textView else { return }

        var needsStylingUpdate = false

        if textView.string != text {
            let selectedRanges = textView.selectedRanges

            // Clear undo stack and disable undo for programmatic text changes
            textView.undoManager?.removeAllActions()
            textView.string = text

            needsStylingUpdate = true

            let validRanges = selectedRanges.compactMap { rangeValue -> NSRange? in
                let range = rangeValue.rangeValue
                return range.location + range.length <= text.count ? range : nil
            }
            if !validRanges.isEmpty {
                textView.setSelectedRanges(validRanges.map { NSValue(range: $0) }, affinity: .downstream, stillSelecting: false)
            }
        }

        // In diff mode, editing is disabled
        textView.isEditable = isEditable && !isDiffMode

        // Update diff mode state
        if textView.isDiffMode != isDiffMode {
            textView.isDiffMode = isDiffMode
            needsStylingUpdate = true
        }

        if textView.diffSegments != diffSegments {
            textView.diffSegments = diffSegments
            needsStylingUpdate = true
        }

        if textView.frozenRanges != frozenRanges {
            textView.frozenRanges = frozenRanges
            needsStylingUpdate = true
        }

        if textView.modifiedRanges != modifiedRanges {
            textView.modifiedRanges = modifiedRanges
            needsStylingUpdate = true
        }

        if regeneratingRanges != textView.regeneratingRanges {
            textView.regeneratingRanges = regeneratingRanges
            needsStylingUpdate = true
            textView.updateRegeneratingRects()
        }

        if needsStylingUpdate {
            applyTextStyling(to: textView)
            containerView.updateIntrinsicSize()
        }
    }

    private func applyTextStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()

        let defaultFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        // Match SwiftUI's .lineSpacing() behavior
        paragraphStyle.lineSpacing = lineHeight
        paragraphStyle.lineHeightMultiple = 0.0

        textStorage.setAttributes([
            .font: defaultFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        // Apply diff styling if in diff mode
        // Note: With swap merging, delete segments are absorbed into inserts, so we only style inserts
        if isDiffMode {
            for segment in diffSegments where segment.range.location + segment.range.length <= textStorage.length {
                switch segment.type {
                case .insert:
                    // Green text with green background for inserted/swapped text
                    textStorage.addAttributes([
                        .foregroundColor: SelectableTextViewConstants.diffInsertForegroundColor,
                        .backgroundColor: SelectableTextViewConstants.diffInsertBackgroundColor
                    ], range: segment.range)
                case .delete:
                    // Red text with strikethrough for deleted text (shown inline)
                    textStorage.addAttributes([
                        .foregroundColor: SelectableTextViewConstants.diffDeleteForegroundColor,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: SelectableTextViewConstants.diffDeleteForegroundColor
                    ], range: segment.range)
                case .equal:
                    // Equal text keeps default styling (white foreground, clear background)
                    break
                }
            }
        } else {
            // Apply modified ranges styling (skip if being regenerated)
            for modifiedRange in modifiedRanges where modifiedRange.location + modifiedRange.length <= textStorage.length {
                let isBeingRegenerated = regeneratingRanges.contains { NSEqualRanges($0, modifiedRange) || NSIntersectionRange($0, modifiedRange).length > 0 }
                if !isBeingRegenerated {
                    textStorage.addAttribute(.backgroundColor, value: SelectableTextViewConstants.modifiedBackgroundColor, range: modifiedRange)
                }
            }

            // Apply frozen ranges styling
            let italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)
            for frozenRange in frozenRanges where frozenRange.location + frozenRange.length <= textStorage.length {
                textStorage.addAttributes([
                    .font: italicFont,
                    .backgroundColor: SelectableTextViewConstants.frozenBackgroundColor
                ], range: frozenRange)
            }

            // Hide text being regenerated (shimmer will be shown on top)
            for regeneratingRange in regeneratingRanges where regeneratingRange.location + regeneratingRange.length <= textStorage.length {
                textStorage.addAttributes([
                    .foregroundColor: NSColor.clear,
                    .backgroundColor: NSColor.clear
                ], range: regeneratingRange)
            }
        }

        textStorage.endEditing()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextView
        weak var textView: SelectableNSTextView?
        weak var containerView: SelectableTextContainerView?

        // Track pending edit for range adjustment
        private var pendingEditLocation: Int?
        private var pendingLengthDelta: Int?

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        @MainActor func handleSelectionChange(_ ranges: [NSRange]) { parent.onSelectionChange?(ranges, textView) }
        @MainActor func handleFrozenClick(_ range: NSRange) { parent.onFrozenClick?(range, textView) }
        @MainActor func handleModifiedClick(_ range: NSRange) { parent.onModifiedClick?(range, textView) }
        @MainActor func handleClickOutsideSelection() { parent.onClickOutsideSelection?() }
        @MainActor func handleRegeneratingRectsChange(_ rects: [CGRect]) { parent.onRegeneratingRectsChange?(rects) }
        @MainActor func handleHeightChange(_ height: CGFloat) { parent.onHeightChange?(height) }
        @MainActor func handleDiffSegmentHover(_ segment: DiffSegment) { parent.onDiffSegmentHover?(segment, textView) }
        @MainActor func handleDiffSegmentUnhover() { parent.onDiffSegmentUnhover?() }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Adjust frozen and modified ranges based on the edit
            if let editLocation = pendingEditLocation, let lengthDelta = pendingLengthDelta {
                QuickEditSelectionService.shared.adjustRangesAfterEdit(
                    editLocation: editLocation,
                    lengthDelta: lengthDelta
                )
                pendingEditLocation = nil
                pendingLengthDelta = nil
            }

            // Reset styling for the entire text to remove inherited frozen/modified styles
            // This is needed because NSTextView applies adjacent character attributes to new text
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                let fullRange = NSRange(location: 0, length: textStorage.length)
                let defaultFont = NSFont.systemFont(ofSize: parent.fontSize, weight: .regular)
                textStorage.addAttributes([
                    .font: defaultFont,
                    .foregroundColor: parent.textColor,
                    .backgroundColor: NSColor.clear
                ], range: fullRange)
            }

            parent.text = textView.string
            // Update intrinsic size when text changes via user editing
            containerView?.updateIntrinsicSize()
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Never block user editing - frozen/modified ranges are visual indicators only
            // But clear any frozen/modified ranges that are being edited
            let selectionService = QuickEditSelectionService.shared
            let editLocation = affectedCharRange.location

            // Calculate length delta for adjusting other ranges
            let oldLength = affectedCharRange.length
            let newLength = replacementString?.count ?? 0
            pendingEditLocation = editLocation
            pendingLengthDelta = newLength - oldLength

            // Clear any frozen range containing the edit location
            selectionService.unfreezeContaining(location: editLocation)

            // Clear any segment containing the edit location (handles both insertion and deletion)
            selectionService.clearSegmentContaining(location: editLocation)

            QuickEditSelectionCoordinator.shared.hideAllHints()

            return parent.isEditable
        }
    }
}

// MARK: - SelectableTextContainerView

class SelectableTextContainerView: NSView {
    private(set) var textView: SelectableNSTextView?
    private var scrollView: NSScrollView?
    private var documentView: FlippedView?
    private let maxHeight: CGFloat?
    private var lastKnownWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0
    var onHeightChange: ((CGFloat) -> Void)?

    init(maxHeight: CGFloat? = nil) {
        self.maxHeight = maxHeight
        super.init(frame: .zero)
        // High content hugging priority to shrink when content is smaller
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with textView: SelectableNSTextView) {
        self.textView = textView

        // Clip content to bounds
        wantsLayer = true
        layer?.masksToBounds = true

        if maxHeight != nil {
            // Use scroll view for scrollable content
            let scrollView = NSScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.scrollerStyle = .overlay

            let documentView = FlippedView()
            documentView.addSubview(textView)
            scrollView.documentView = documentView

            addSubview(scrollView)
            self.scrollView = scrollView
            self.documentView = documentView

            // Pin scroll view to edges
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            // Direct embedding without scroll view
            addSubview(textView)
        }
    }

    override var intrinsicContentSize: NSSize {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 20)
        }

        // Ensure text container has correct width before calculating height
        if lastKnownWidth > 0 {
            textContainer.containerSize = NSSize(width: lastKnownWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        // Add small buffer for line spacing at the end
        var height = max(20, ceil(usedRect.height) + 4)

        if let maxHeight = maxHeight {
            height = min(height, maxHeight)
        }

        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func layout() {
        super.layout()

        guard let textView = textView else { return }

        let currentWidth = bounds.width
        guard currentWidth > 0 else { return }

        // Update text container width if it changed
        if currentWidth != lastKnownWidth {
            lastKnownWidth = currentWidth
            textView.textContainer?.containerSize = NSSize(width: currentWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        if let _ = scrollView, let documentView = documentView,
           let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            // Scrollable mode - update document view size based on content
            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = ceil(layoutManager.usedRect(for: textContainer).height)

            // Set document and text view frames (add buffer for line spacing)
            let documentHeight = max(20, contentHeight + 4)
            documentView.frame = CGRect(x: 0, y: 0, width: currentWidth, height: documentHeight)
            textView.frame = CGRect(x: 0, y: 0, width: currentWidth, height: contentHeight)
        } else {
            // Direct mode (no scrolling)
            textView.frame = bounds
        }

        // Notify SwiftUI of height changes during layout
        let newHeight = intrinsicContentSize.height
        if newHeight != lastReportedHeight && newHeight > 0 {
            lastReportedHeight = newHeight
            // Only invalidate intrinsic content size when height actually changes to avoid layout cycles
            invalidateIntrinsicContentSize()
            // Dispatch to avoid modifying SwiftUI state during layout
            DispatchQueue.main.async { [weak self] in
                self?.onHeightChange?(newHeight)
            }
        }
    }

    func updateIntrinsicSize() {
        invalidateIntrinsicContentSize()
        needsLayout = true

        // Notify SwiftUI of the new height
        let newHeight = intrinsicContentSize.height
        if newHeight != lastReportedHeight && newHeight > 0 {
            lastReportedHeight = newHeight
            onHeightChange?(newHeight)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // When the view is added to a window, it gets proper bounds.
        // Trigger layout to update lastKnownWidth and recalculate height.
        if window != nil {
            needsLayout = true
            DispatchQueue.main.async { [weak self] in
                self?.updateIntrinsicSize()
            }
        }
    }
}

// MARK: - FlippedView

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - SelectableNSTextView

class SelectableNSTextView: NSTextView {

    var frozenRanges: [NSRange] = []
    var modifiedRanges: [NSRange] = []
    var regeneratingRanges: [NSRange] = []

    // Diff view properties
    var isDiffMode: Bool = false
    var diffSegments: [DiffSegment] = []

    var onSelectionChange: (([NSRange]) -> Void)?
    var onFrozenClick: ((NSRange) -> Void)?
    var onModifiedClick: ((NSRange) -> Void)?
    var onClickOutsideSelection: (() -> Void)?
    var onRegeneratingRectsChange: (([CGRect]) -> Void)?
    var onDiffSegmentHover: ((DiffSegment) -> Void)?
    var onDiffSegmentUnhover: (() -> Void)?

    private var lastSelectedRanges: [NSRange] = []
    private var hoveredDiffSegment: DiffSegment?
    private var trackingArea: NSTrackingArea?
    /// The modified range that was dismissed (hint hidden) - don't show hint again while cursor stays in this range
    private var dismissedModifiedRange: NSRange?
    /// Flag to suppress selection change callbacks during special click handling
    private var isHandlingSpecialClick: Bool = false

    // MARK: - Tracking Area Setup

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking area
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        // Add new tracking area for mouse movement detection (for diff segment hover)
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        guard isDiffMode else {
            // Clear any hovered segment when not in diff mode
            if hoveredDiffSegment != nil {
                hoveredDiffSegment = nil
                onDiffSegmentUnhover?()
            }
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let characterIndex = characterIndexForInsertion(at: point)

        // Check if hovering over an insert or delete segment (both can be undone)
        var newHoveredSegment: DiffSegment? = nil
        for segment in diffSegments where (segment.type == .insert || segment.type == .delete) &&
            NSLocationInRange(characterIndex, segment.range) {
            newHoveredSegment = segment
            break
        }

        // If hovered segment changed, notify
        if newHoveredSegment?.id != hoveredDiffSegment?.id {
            if let segment = newHoveredSegment {
                hoveredDiffSegment = segment
                onDiffSegmentHover?(segment)
            } else if hoveredDiffSegment != nil {
                hoveredDiffSegment = nil
                onDiffSegmentUnhover?()
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        // Clear hovered segment when mouse exits the view
        if hoveredDiffSegment != nil {
            hoveredDiffSegment = nil
            onDiffSegmentUnhover?()
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)

        // Don't trigger selection change during special click handling (frozen/modified clicks)
        // to avoid hint conflicts
        guard !isHandlingSpecialClick else { return }

        if !stillSelecting {
            let nsRanges = ranges.map { $0.rangeValue }
            if nsRanges != lastSelectedRanges {
                lastSelectedRanges = nsRanges
                onSelectionChange?(nsRanges)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let characterIndex = characterIndexForInsertion(at: point)

        var handledSpecialClick = false

        // In diff mode, editing is disabled but selection is allowed
        // Diff segment hover is handled by mouseMoved, not click
        if isDiffMode {
            super.mouseDown(with: event)
            return
        }

        // Handle frozen range click - show hint but still allow normal selection
        for frozenRange in frozenRanges where NSLocationInRange(characterIndex, frozenRange) && event.clickCount == 1 {
            isHandlingSpecialClick = true
            handledSpecialClick = true
            onFrozenClick?(frozenRange)
            break
        }

        // Handle modified range click - show hint but still allow normal selection
        if !handledSpecialClick {
            for modifiedRange in modifiedRanges where NSLocationInRange(characterIndex, modifiedRange) && event.clickCount == 1 {
                // If this range was dismissed, skip showing hint again but still mark as special click
                // to avoid triggering selection hint
                isHandlingSpecialClick = true
                handledSpecialClick = true

                if let dismissed = dismissedModifiedRange, NSEqualRanges(dismissed, modifiedRange) {
                    break
                }

                let wasHintVisible = SelectionHintWindowController.shared.isVisible
                let wasShowingThisRange = SelectionHintWindowController.shared.associatedRange.map { NSEqualRanges($0, modifiedRange) } ?? false

                onModifiedClick?(modifiedRange)

                // If hint was visible for this range, we're toggling to editable mode
                if wasHintVisible && wasShowingThisRange {
                    dismissedModifiedRange = modifiedRange
                }
                break
            }
        }

        // Click outside any special range - clear the dismissed state
        let isInModifiedRange = modifiedRanges.contains { NSLocationInRange(characterIndex, $0) }
        if !isInModifiedRange {
            dismissedModifiedRange = nil
        }

        let selectedRanges = self.selectedRanges.map { $0.rangeValue }
        let clickInSelection = selectedRanges.contains { NSLocationInRange(characterIndex, $0) }

        if !clickInSelection && !selectedRanges.isEmpty && selectedRanges.first?.length ?? 0 > 0 {
            onClickOutsideSelection?()
        }

        // Always call super to allow normal text selection and editing
        super.mouseDown(with: event)

        // Reset the flag after mouseDown completes
        isHandlingSpecialClick = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let layoutManager = layoutManager, let textContainer = textContainer else { return }

        NSGraphicsContext.saveGraphicsState()

        for frozenRange in frozenRanges where frozenRange.location + frozenRange.length <= string.count {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: frozenRange, actualCharacterRange: nil)
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                let adjustedRect = rect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
                SelectableTextViewConstants.frozenBackgroundColor.setFill()
                NSBezierPath(roundedRect: adjustedRect, xRadius: 2, yRadius: 2).fill()
            }
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    func boundingRect(for range: NSRange) -> NSRect? {
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return nil }
        guard range.location + range.length <= string.count else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var boundingRect = NSRect.zero

        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            boundingRect = boundingRect == .zero ? rect : boundingRect.union(rect)
        }

        return convert(boundingRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y), to: nil)
    }

    func screenRect(for range: NSRange) -> NSRect? {
        guard let boundingRect = boundingRect(for: range), let window = window else { return nil }
        return window.convertToScreen(boundingRect)
    }

    func localRect(for range: NSRange) -> NSRect? {
        let rects = localRects(for: range)
        guard !rects.isEmpty else { return nil }
        return rects.reduce(rects[0]) { $0.union($1) }
    }

    func localRects(for range: NSRange) -> [NSRect] {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return []
        }
        
        guard range.location + range.length <= string.count else {
            return []
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [NSRect] = []
        
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineFragmentRect, usedRect, _, lineGlyphRange, _ in
            // Get the intersection of the line's glyph range with our target range
            let intersectionRange = NSIntersectionRange(lineGlyphRange, glyphRange)
            
            guard intersectionRange.length > 0 else { return }

            // Get the exact bounding rect for just the glyphs in our range on this line
            let lineRect = layoutManager.boundingRect(forGlyphRange: intersectionRange, in: textContainer)

            rects.append(lineRect)
        }

        return rects
    }

    func updateRegeneratingRects() {
        let ranges = regeneratingRanges
        let callback = onRegeneratingRectsChange

        // Use asyncAfter to ensure the layout is fully updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self,
                  let layoutManager = self.layoutManager,
                  let textContainer = self.textContainer else {
                callback?([])
                
                return
            }
            
            // Ensure layout is up to date before calculating rects
            layoutManager.ensureLayout(for: textContainer)
            
            // Get all line rects for all regenerating ranges
            let rects = ranges.flatMap { self.localRects(for: $0) }
            
            callback?(rects)
        }
    }
}
