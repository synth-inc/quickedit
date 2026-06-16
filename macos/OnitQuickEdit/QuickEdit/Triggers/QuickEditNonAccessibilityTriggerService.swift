//
//  QuickEditNonAccessibilityTriggerService.swift
//  Onit
//
//  Trigger service that detects text selection using image diff instead of accessibility APIs.
//  Captures screenshots before/after selection events and uses image diff to find selection bounds.
//

import AppKit
import Combine
import CoreGraphics
import Defaults
import Foundation
import UniformTypeIdentifiers

// MARK: - Configuration

struct NonAccessibilityTriggerConfig {
    /// Tile size for image diff (smaller = more precise, but slower)
    var tileSize: Int = 20

    /// Delay before capturing "after" screenshot (ms)
    var captureDelayMs: UInt64 = 100

    /// Debounce interval for repeated events (ms)
    var debounceIntervalMs: UInt64 = 150

    /// Pixel difference threshold for considering a pixel "changed"
    /// Lower values are more sensitive to subtle color changes (e.g., blue highlight on blue background)
    var pixelDiffThreshold: UInt8 = 10

    /// Enable saving before/after screenshots to ~/Documents/OnitDebug/
    var saveDebugScreenshots: Bool = true

    /// Minimum region area in pixels squared for tile grouping
    /// Very small regions are filtered out before ML inference for efficiency
    var minimumRegionArea: CGFloat = 500
}

// MARK: - Trigger Service

@MainActor
final class QuickEditNonAccessibilityTriggerService: NSObject {

    // MARK: - Key Codes

    /// macOS virtual key codes for keys that can trigger text selection
    private enum KeyCode: UInt16 {
        // Arrow keys
        case leftArrow = 123
        case rightArrow = 124
        case downArrow = 125
        case upArrow = 126

        // Navigation keys
        case home = 115
        case end = 119
        case pageUp = 116
        case pageDown = 121

        // Select all
        case a = 0

        // Modifier keys
        case shift = 56
        case rightShift = 60
        case command = 55
        case rightCommand = 54
    }

    // MARK: - Singleton

    static let shared = QuickEditNonAccessibilityTriggerService()

    // MARK: - Properties

    weak var delegate: QuickEditTriggerServiceDelegate?

    var config = NonAccessibilityTriggerConfig()

    private var isMonitoring = false
    private var debounceTask: Task<Void, Never>?

    private var isDragging = false
    private var isShiftDown = false
    private var isCommandDown = false

    // Screenshot state
    private var beforeScreenshot: CGImage?
    private var beforeScreenshotAppName: String?
    private var beforeScreenshotWindowTitle: String?
    private var beforeScreenshotWindowFrame: CGRect?
    private var captureTask: Task<Void, Never>?

    // Cleanup task for screenshots that aren't used (e.g., simple click with no follow-up action)
    private var screenshotCleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }

        MouseNotificationManager.shared.addDelegate(self)
        KeystrokeNotificationManager.shared.addDelegate(self)

        isMonitoring = true
        print("[NonAccessibilityTrigger] Started monitoring")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        MouseNotificationManager.shared.removeDelegate(self)
        KeystrokeNotificationManager.shared.removeDelegate(self)

        debounceTask?.cancel()
        debounceTask = nil
        isDragging = false
        isShiftDown = false
        clearBeforeScreenshot()

        isMonitoring = false
        print("[NonAccessibilityTrigger] Stopped monitoring")
    }

    // MARK: - Screenshot Management

    /// Atomically checks if a before screenshot capture is needed and starts one if so.
    /// This prevents race conditions where multiple events could trigger simultaneous captures.
    /// - Parameter reason: Description of why the capture is being requested
    /// - Returns: true if a new capture was started, false if one was already in progress or available
    @discardableResult
    private func captureBeforeScreenshotIfNeeded(reason: String) -> Bool {
        // Atomic check: only capture if we don't have a screenshot AND no capture is in progress
        guard beforeScreenshot == nil && captureTask == nil else {
            return false
        }
        captureBeforeScreenshot(reason: reason)
        return true
    }

    private func captureBeforeScreenshot(reason: String) {
        captureTask?.cancel()

        captureTask = Task {
            guard !Task.isCancelled else { return }

            guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
                  let appName = frontmostApp.localizedName,
                  frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

            // Get the actual foreground window to ensure we capture the right one
            let pid = frontmostApp.processIdentifier
            let mainWindow = pid.firstMainWindow
            let windowTitle = mainWindow?.title()
            let windowFrame = mainWindow?.getFrame()

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.beforeScreenshotAppName = appName
                self.beforeScreenshotWindowTitle = windowTitle
                self.beforeScreenshotWindowFrame = windowFrame
            }

            do {
                let screenshot = try await ScreenRecordingManager.captureWindowScreenshot(
                    from: appName,
                    appTitle: windowTitle,
                    windowFrame: windowFrame
                )
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.beforeScreenshot = screenshot
                }
            } catch {
                // Screenshot capture failed - will be handled in processTrigger
            }
        }
    }

    private func clearBeforeScreenshot() {
        // Don't clear if shift or command is still held - user might extend selection or use Cmd+A
        guard !isShiftDown && !isCommandDown else { return }

        captureTask?.cancel()
        captureTask = nil
        beforeScreenshot = nil
        beforeScreenshotAppName = nil
        beforeScreenshotWindowTitle = nil
        beforeScreenshotWindowFrame = nil
        screenshotCleanupTask?.cancel()
        screenshotCleanupTask = nil
    }

    /// Schedules cleanup of the before screenshot if no action follows within the timeout.
    /// This prevents stale screenshots from being used for unrelated actions.
    private func scheduleScreenshotCleanup() {
        screenshotCleanupTask?.cancel()
        screenshotCleanupTask = Task { @MainActor in
            do {
                // Wait 500ms for a follow-up action (drag, double-click, etc.)
                try await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }

                // If we're not dragging and screenshot still exists, clean it up
                if !isDragging && beforeScreenshot != nil {
                    print("[NonAccessibilityTrigger] Cleaning up unused screenshot (no follow-up action)")
                    clearBeforeScreenshot()
                }
            } catch {
                // Task was cancelled (a legitimate action used the screenshot)
            }
        }
    }

    /// Cancels any pending screenshot cleanup (called when a legitimate action uses the screenshot)
    private func cancelScreenshotCleanup() {
        screenshotCleanupTask?.cancel()
        screenshotCleanupTask = nil
    }

    // MARK: - Trigger Scheduling

    private func scheduleTrigger(reason: String, afterDelay: UInt64 = 0) {
        // Cancel any existing debounce task
        debounceTask?.cancel()

        let eventTime = CFAbsoluteTimeGetCurrent()

        debounceTask = Task { @MainActor in
            do {
                // Wait for debounce interval
                try await Task.sleep(nanoseconds: config.debounceIntervalMs * 1_000_000)
                guard !Task.isCancelled else { return }

                // Check if app is excluded or paused
                guard shouldTriggerForCurrentApp() else {
                    print("[NonAccessibilityTrigger] Skipped (app excluded/paused)")
                    return
                }

                let debounceMs = (CFAbsoluteTimeGetCurrent() - eventTime) * 1000
                print("[NonAccessibilityTrigger] Processing trigger - \(reason) (debounce: \(String(format: "%.0f", debounceMs))ms)")
                await processTrigger(reason: reason, afterDelay: afterDelay)
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    private func shouldTriggerForCurrentApp() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontmostApp.localizedName else {
            return true
        }

        // Check if QuickEdit is enabled via the unified FeatureDisableManager
        return FeatureDisableManager.shared.isEnabled(.quickEdit)
    }

    // MARK: - Trigger Processing

    /// Checkpoint function type for timing measurements
    private typealias CheckpointFunc = (String) -> Void

    /// Creates a checkpoint function for timing measurements
    private func makeCheckpointFunc() -> (startTime: CFAbsoluteTime, checkpoint: CheckpointFunc) {
        let startTime = CFAbsoluteTimeGetCurrent()
        var lastCheckpoint = startTime

        let checkpoint: CheckpointFunc = { name in
            let now = CFAbsoluteTimeGetCurrent()
            let stepMs = (now - lastCheckpoint) * 1000
            let totalMs = (now - startTime) * 1000
            print("[NonAccessibilityTrigger] ⏱ \(name): \(String(format: "%.1f", stepMs))ms (total: \(String(format: "%.1f", totalMs))ms)")
            lastCheckpoint = now
        }

        return (startTime, checkpoint)
    }

    /// Result of preparing screenshots for comparison
    private struct ScreenshotPair {
        let beforeImage: CGImage
        let afterImage: CGImage
        let appName: String
    }

    /// Waits for before screenshot and captures after screenshot
    /// - Parameter additionalDelay: Extra delay in ms before capturing after screenshot (for instant shortcuts like Cmd+A)
    private func prepareScreenshots(checkpoint: CheckpointFunc, additionalDelay: UInt64 = 0) async -> ScreenshotPair? {
        // Wait for the before screenshot capture to complete
        if let task = captureTask {
            await task.value
        }
        checkpoint("Before screenshot ready")

        guard let beforeImage = beforeScreenshot,
              let appName = beforeScreenshotAppName else {
            print("[NonAccessibilityTrigger] No before screenshot available")
            return nil
        }

        // Verify the frontmost app hasn't changed
        guard let currentApp = NSWorkspace.shared.frontmostApplication,
              currentApp.localizedName == appName else {
            print("[NonAccessibilityTrigger] App changed since before screenshot, aborting")
            clearBeforeScreenshot()
            return nil
        }

        // Wait a bit for the selection highlight to render
        // Additional delay is used for instant shortcuts like Cmd+A where the selection happens immediately
        let totalDelay = config.captureDelayMs + additionalDelay
        try? await Task.sleep(nanoseconds: totalDelay * 1_000_000)
        checkpoint("Capture delay (\(totalDelay)ms)")

        // Get fresh window frame in case the window moved
        let currentWindowFrame = currentApp.processIdentifier.firstMainWindow?.getFrame()

        // Capture after screenshot using the same window title to ensure we get the same window
        let afterImage: CGImage
        do {
            afterImage = try await ScreenRecordingManager.captureWindowScreenshot(
                from: appName,
                appTitle: beforeScreenshotWindowTitle,
                windowFrame: currentWindowFrame
            )
            checkpoint("After screenshot captured (\(afterImage.width)x\(afterImage.height))")
        } catch {
            print("[NonAccessibilityTrigger] Failed to capture after screenshot: \(error)")
            return nil
        }

        // Verify dimensions match
        guard beforeImage.width == afterImage.width && beforeImage.height == afterImage.height else {
            print("[NonAccessibilityTrigger] Screenshot dimensions don't match: before=\(beforeImage.width)x\(beforeImage.height), after=\(afterImage.width)x\(afterImage.height)")
            return nil
        }

        return ScreenshotPair(beforeImage: beforeImage, afterImage: afterImage, appName: appName)
    }

    /// Result of background image analysis (image diff + ML detection)
    private struct ImageAnalysisResult: Sendable {
        let groupedRegions: [CGRect]
        let validRegions: [CGRect]?
    }

    private func processTrigger(reason: String, afterDelay: UInt64 = 0) async {
        let (_, checkpoint) = makeCheckpointFunc()

        // Step 1: Prepare before/after screenshots
        guard let screenshots = await prepareScreenshots(checkpoint: checkpoint, additionalDelay: afterDelay) else {
            return
        }

        let beforeImage = screenshots.beforeImage
        let afterImage = screenshots.afterImage
        let appName = screenshots.appName

        // Save debug screenshots if enabled
        #if DEBUG || ONIT_BETA
        if config.saveDebugScreenshots {
            saveDebugScreenshots(before: beforeImage, after: afterImage, reason: reason)
        }
        #endif

        // Steps 2-3: Run CPU-intensive image diff + ML detection off the main thread
        let currentConfig = self.config
        let analysis: ImageAnalysisResult? = await Task.detached(priority: .userInitiated) {
            // Step 2: Detect changed regions via image diff
            let changedRegions: [ImageDifferenceRegion]
            do {
                let (regions, _, _) = try ImageDifferenceDetector.computeChangedRegions(
                    before: beforeImage,
                    after: afterImage,
                    tileSize: currentConfig.tileSize,
                    tileOverlapX: 0,
                    tileOverlapY: 0,
                    sampleStride: 2,
                    pixelDiffThreshold: currentConfig.pixelDiffThreshold,
                    tileChangeRatioThreshold: 0.01
                )
                changedRegions = regions
            } catch {
                print("[NonAccessibilityTrigger] Image diff failed: \(error)")
                return nil
            }

            guard !changedRegions.isEmpty else {
                print("[NonAccessibilityTrigger] No changed regions detected")
                return nil
            }

            // Group changed tiles into contiguous regions
            let groupedRegions = QuickEditNonAccessibilityTriggerService.groupContiguousRegions(
                changedRegions, tileSize: currentConfig.tileSize
            )

            // Step 3: Filter by area and run ML highlight detection
            let candidateRegions = groupedRegions.filter { region in
                region.width * region.height >= currentConfig.minimumRegionArea
            }

            guard !candidateRegions.isEmpty else {
                print("[NonAccessibilityTrigger] No candidate regions after area filter")
                return ImageAnalysisResult(groupedRegions: groupedRegions, validRegions: nil)
            }

            print("[NonAccessibilityTrigger] Analyzing \(candidateRegions.count) candidate regions with ML model...")

            let highlightResults = HighlightDetectorService.shared.detectHighlights(
                beforeImage: beforeImage,
                afterImage: afterImage,
                regions: candidateRegions
            )

            guard !highlightResults.isEmpty else {
                print("[NonAccessibilityTrigger] No highlighted text regions detected by ML model")
                return ImageAnalysisResult(groupedRegions: groupedRegions, validRegions: nil)
            }

            return ImageAnalysisResult(
                groupedRegions: groupedRegions,
                validRegions: highlightResults.map { $0.region }
            )
        }.value

        checkpoint("Image analysis (background)")

        // Back on main thread — handle results
        guard let analysis else {
            return
        }

        guard let validRegions = analysis.validRegions else {
            return
        }

        // Step 4: Pick region closest to mouse
        let mouseLocation = NSEvent.mouseLocation
        let selectedRegion = pickRegionClosestToMouse(regions: validRegions, mouseLocation: mouseLocation, appName: appName)
        checkpoint("Region selection")

        let aspectRatio = selectedRegion.width / selectedRegion.height
        print("[NonAccessibilityTrigger] Selected region: \(Int(selectedRegion.width))x\(Int(selectedRegion.height)) | aspect: \(String(format: "%.2f", aspectRatio)) (closest to mouse at \(mouseLocation))")

        // Step 5: Convert to screen coordinates and trigger QuickEdit
        await triggerQuickEdit(with: selectedRegion, appName: appName, reason: reason, checkpoint: checkpoint)
        checkpoint("Hint displayed ✅")
    }

    // MARK: - Region Grouping

    private nonisolated static func groupContiguousRegions(_ regions: [ImageDifferenceRegion], tileSize: Int) -> [CGRect] {
        guard !regions.isEmpty else { return [] }

        // Build spatial grid for O(1) neighbor lookup
        // Key: (gridX, gridY), Value: index in regions array
        var grid: [Int: [Int: Int]] = [:]
        for (index, region) in regions.enumerated() {
            let gridX = Int(region.rect.minX) / tileSize
            let gridY = Int(region.rect.minY) / tileSize
            if grid[gridX] == nil {
                grid[gridX] = [:]
            }
            grid[gridX]![gridY] = index
        }

        // Union-Find for efficient grouping
        var parent = Array(0..<regions.count)
        var rank = [Int](repeating: 0, count: regions.count)

        func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x])
            }
            return parent[x]
        }

        func union(_ x: Int, _ y: Int) {
            let rootX = find(x)
            let rootY = find(y)
            if rootX != rootY {
                if rank[rootX] < rank[rootY] {
                    parent[rootX] = rootY
                } else if rank[rootX] > rank[rootY] {
                    parent[rootY] = rootX
                } else {
                    parent[rootY] = rootX
                    rank[rootX] += 1
                }
            }
        }

        // Connect adjacent tiles (8 directions)
        let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

        for (index, region) in regions.enumerated() {
            let gridX = Int(region.rect.minX) / tileSize
            let gridY = Int(region.rect.minY) / tileSize

            for (dx, dy) in directions {
                let neighborX = gridX + dx
                let neighborY = gridY + dy
                if let neighborIndex = grid[neighborX]?[neighborY] {
                    union(index, neighborIndex)
                }
            }
        }

        // Group regions by their root
        var groups: [Int: [CGRect]] = [:]
        for (index, region) in regions.enumerated() {
            let root = find(index)
            groups[root, default: []].append(region.rect)
        }

        // Compute bounding box for each group
        return groups.values.map { group in
            let minX = group.map { $0.minX }.min() ?? 0
            let minY = group.map { $0.minY }.min() ?? 0
            let maxX = group.map { $0.maxX }.max() ?? 0
            let maxY = group.map { $0.maxY }.max() ?? 0
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    // MARK: - Debug Screenshot Saving

    private func saveDebugScreenshots(before: CGImage, after: CGImage, reason: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[NonAccessibilityTrigger] Cannot find Documents directory")
            return
        }

        let debugDir = documentsURL.appendingPathComponent("OnitDebug", isDirectory: true)

        // Create debug directory if needed
        if !fileManager.fileExists(atPath: debugDir.path) {
            do {
                try fileManager.createDirectory(at: debugDir, withIntermediateDirectories: true)
            } catch {
                print("[NonAccessibilityTrigger] Failed to create debug directory: \(error)")
                return
            }
        }

        // Create timestamp-based prefix for grouping before/after pairs
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = dateFormatter.string(from: Date())

        // Sanitize reason for filename
        let sanitizedReason = reason.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let beforeURL = debugDir.appendingPathComponent("\(timestamp)_\(sanitizedReason)_before.png")
        let afterURL = debugDir.appendingPathComponent("\(timestamp)_\(sanitizedReason)_after.png")

        // Save before image
        if let beforeDestination = CGImageDestinationCreateWithURL(beforeURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(beforeDestination, before, nil)
            if CGImageDestinationFinalize(beforeDestination) {
                print("[NonAccessibilityTrigger] Saved before screenshot: \(beforeURL.lastPathComponent)")
            }
        }

        // Save after image
        if let afterDestination = CGImageDestinationCreateWithURL(afterURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(afterDestination, after, nil)
            if CGImageDestinationFinalize(afterDestination) {
                print("[NonAccessibilityTrigger] Saved after screenshot: \(afterURL.lastPathComponent)")
            }
        }
    }

    // MARK: - Region Selection

    private func pickRegionClosestToMouse(regions: [CGRect], mouseLocation: CGPoint, appName: String) -> CGRect {
        guard regions.count > 1 else {
            return regions.first ?? .zero
        }

        // Get window frame to convert coordinates
        // Use convertedToGlobalCoordinateSpace to get macOS screen coordinates (Y=0 at bottom)
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let mainWindow = pid.firstMainWindow,
              let windowFrame = mainWindow.getFrame(convertedToGlobalCoordinateSpace: true) else {
            // Fallback: return first region if we can't get window frame
            return regions.first ?? .zero
        }

        var closestRegion = regions[0]
        var closestDistance = CGFloat.infinity

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0

        for region in regions {
            // Convert region center from image coordinates (pixels) to screen coordinates (points)
            let screenCenterX = windowFrame.minX + region.midX / scaleFactor
            let screenCenterY = windowFrame.minY + region.midY / scaleFactor
            let distance = hypot(screenCenterX - mouseLocation.x, screenCenterY - mouseLocation.y)

            if distance < closestDistance {
                closestDistance = distance
                closestRegion = region
            }
        }

        return closestRegion
    }

    // MARK: - QuickEdit Trigger

    private func triggerQuickEdit(with region: CGRect, appName: String, reason: String, checkpoint: @escaping (String) -> Void) async {
        // Get the window frame to convert coordinates
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let mainWindow = pid.firstMainWindow,
              let windowFrame = mainWindow.getFrame(convertedToGlobalCoordinateSpace: true) else {
            print("[NonAccessibilityTrigger] Cannot get window frame for coordinate conversion")
            return
        }

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let selectionRect = CGRect(
            x: windowFrame.minX + region.minX / scaleFactor,
            y: windowFrame.minY + region.minY / scaleFactor,
            width: region.width / scaleFactor,
            height: region.height / scaleFactor
        )

        // Note: We intentionally don't copy text here. The copy (Cmd+C) will be triggered
        // later when the user actually clicks "Improve" or "Edit", via QuickEditFlowService.
        // This avoids: clipboard disruption, Edit menu flashing, and error sounds when
        // the hint appears for non-text selections.

        checkpoint("Coordinate conversion")

        // Calculate display position using SmartUIPositioner or fallback
        let positioningResult = await calculateDisplayPosition(selectionRect: selectionRect)
        checkpoint("Smart positioning")

        // Create QuickEditRequest - selectedText is nil, will be retrieved later
        let request = QuickEditRequest(
            applicationName: appName,
            textBefore: nil,
            selectedText: nil,
            selectedTextBounds: selectionRect,
            displayArea: positioningResult.displayArea,
            isDisplayedBelowHighlightedText: positioningResult.isBelow,
            cursorTextFrame: selectionRect,
            smartHintPosition: positioningResult.smartHintPosition
        )

        // Notify delegate - hint shows immediately without waiting for copy
        delegate?.triggerQuickEdit(with: request)
    }

    // MARK: - Display Position Calculation

    private struct DisplayPositionResult {
        let displayArea: CGRect
        let isBelow: Bool
        let useSmartPositioning: Bool
        let smartHintPosition: CGRect?
    }

    /// Calculates the optimal display position for the hint using SmartUIPositioner when enabled
    private func calculateDisplayPosition(selectionRect: CGRect) async -> DisplayPositionResult {
        let useSmartPositioning = Defaults[.quickEditSmartPositioning]

        if useSmartPositioning {
            // Use SmartUIPositioner to find optimal position that doesn't cover the selection
            let positioningConfig = UIPositioningConfig(
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
                anchorPoint: selectionRect.origin,
                anchorBounds: selectionRect,
                config: positioningConfig
            ) {
                let hintPosition = result.displayArea
                let fullDisplayResult = calculateFullDisplayArea(
                    hintPosition: hintPosition,
                    isDisplayedBelowAnchor: result.isDisplayedBelowAnchor
                )

                return DisplayPositionResult(
                    displayArea: fullDisplayResult.displayArea,
                    isBelow: fullDisplayResult.isBelow,
                    useSmartPositioning: true,
                    smartHintPosition: hintPosition
                )
            }
        }

        // Fallback to simple positioning
        let displayArea = calculateSimpleDisplayArea(selectionRect: selectionRect)
        let isBelow = displayArea.maxY < selectionRect.minY

        return DisplayPositionResult(
            displayArea: displayArea,
            isBelow: isBelow,
            useSmartPositioning: false,
            smartHintPosition: nil
        )
    }

    /// Simple fallback positioning when SmartUIPositioner is disabled or fails
    private func calculateSimpleDisplayArea(selectionRect: CGRect) -> CGRect {
        let hintPadding: CGFloat = 16.0
        let hintHeight = QuickEditConstants.hintHeight
        let screen = NSScreen.screens.first { $0.frame.contains(selectionRect.origin) } ?? NSScreen.main
        let screenMinY = screen?.visibleFrame.minY ?? 0
        let spaceBelow = selectionRect.minY - screenMinY
        let isDisplayedBelow = spaceBelow >= (hintHeight + hintPadding)

        if isDisplayedBelow {
            return CGRect(
                x: selectionRect.minX,
                y: selectionRect.minY - hintHeight - hintPadding,
                width: selectionRect.width,
                height: selectionRect.height
            )
        } else {
            return CGRect(
                x: selectionRect.minX,
                y: selectionRect.maxY + hintPadding,
                width: selectionRect.width,
                height: selectionRect.height
            )
        }
    }

    private struct FullDisplayAreaResult {
        let displayArea: CGRect
        let isBelow: Bool
    }

    /// Calculates the full window display area based on hint position
    private func calculateFullDisplayArea(
        hintPosition: CGRect,
        isDisplayedBelowAnchor: Bool
    ) -> FullDisplayAreaResult {
        let fullWidth = QuickEditConstants.maxWindowWidth
        let fullHeight = QuickEditConstants.maxWindowHeight

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(hintPosition.origin) }) ?? NSScreen.main else {
            return FullDisplayAreaResult(
                displayArea: CGRect(x: hintPosition.minX, y: hintPosition.minY, width: fullWidth, height: fullHeight),
                isBelow: false
            )
        }

        let visibleFrame = screen.visibleFrame

        // Clamp X position to keep window on screen horizontally
        var x = hintPosition.minX
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - fullWidth
        x = max(minX, min(x, maxX))

        let finalIsBelow: Bool
        let finalDisplayArea: CGRect

        if isDisplayedBelowAnchor {
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

    // MARK: - Keyboard Event Handling

    private func handleKeyEvent(_ event: KeystrokeEvent) {
        let keyCode = event.event.keyCode
        let modifiers = event.modifierStates
        let isKeyDown = event.event.type == .keyDown
        let isFlagsChanged = event.event.type == .flagsChanged

        // Track modifier keys via flagsChanged events
        if isFlagsChanged {
            // Track shift key state
            if modifiers.shift && !isShiftDown {
                isShiftDown = true
                captureBeforeScreenshotIfNeeded(reason: "Shift down")
            } else if !modifiers.shift && isShiftDown {
                isShiftDown = false
            }

            // Track command key state
            if modifiers.command && !isCommandDown {
                isCommandDown = true
                captureBeforeScreenshotIfNeeded(reason: "Cmd down")
            } else if !modifiers.command && isCommandDown {
                isCommandDown = false
            }
            return
        }

        // Cmd+A (Select All)
        if modifiers.command && !modifiers.shift && !modifiers.control && !modifiers.option {
            let character = event.event.charactersIgnoringModifiers?.lowercased()
            if character == "a" && isKeyDown {
                // Before screenshot already captured on Cmd down
                // Use 300ms additional delay for instant selection to render
                scheduleTrigger(reason: "Cmd+A (Select All)", afterDelay: 300)
                return
            }
        }

        // Shift-based selection shortcuts
        if modifiers.shift && isKeyDown {
            if isSelectionKey(keyCode) {
                captureBeforeScreenshotIfNeeded(reason: "Shift+Arrow (late capture)")

                let modifierDesc = buildModifierDescription(modifiers)
                let keyDesc = describeKey(keyCode)
                scheduleTrigger(reason: "\(modifierDesc)\(keyDesc)")
            }
        }
    }

    private func isSelectionKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KeyCode.leftArrow.rawValue,
             KeyCode.rightArrow.rawValue,
             KeyCode.upArrow.rawValue,
             KeyCode.downArrow.rawValue,
             KeyCode.home.rawValue,
             KeyCode.end.rawValue,
             KeyCode.pageUp.rawValue,
             KeyCode.pageDown.rawValue:
            return true
        default:
            return false
        }
    }

    private func buildModifierDescription(_ modifiers: (command: Bool, control: Bool, shift: Bool, option: Bool)) -> String {
        var parts: [String] = []
        if modifiers.shift { parts.append("Shift") }
        if modifiers.command { parts.append("Cmd") }
        if modifiers.option { parts.append("Option") }
        if modifiers.control { parts.append("Ctrl") }
        return parts.isEmpty ? "" : parts.joined(separator: "+") + "+"
    }

    private func describeKey(_ keyCode: UInt16) -> String {
        switch keyCode {
        case KeyCode.leftArrow.rawValue: return "Left"
        case KeyCode.rightArrow.rawValue: return "Right"
        case KeyCode.upArrow.rawValue: return "Up"
        case KeyCode.downArrow.rawValue: return "Down"
        case KeyCode.home.rawValue: return "Home"
        case KeyCode.end.rawValue: return "End"
        case KeyCode.pageUp.rawValue: return "PageUp"
        case KeyCode.pageDown.rawValue: return "PageDown"
        case KeyCode.a.rawValue: return "A"
        default: return "Key(\(keyCode))"
        }
    }
}

// MARK: - MouseNotificationDelegate

extension QuickEditNonAccessibilityTriggerService: MouseNotificationDelegate {

    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveDoubleClick event: NSEvent) {
        // Screenshot was already captured on the first click (didReceiveSingleClick)
        // Cancel the cleanup since we're using the screenshot for text selection detection
        cancelScreenshotCleanup()
        scheduleTrigger(reason: "Double-click")
    }

    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveTripleClick event: NSEvent) {
        // Screenshot was already captured on the first click (didReceiveSingleClick)
        // Cancel the cleanup since we're using the screenshot for text selection detection
        cancelScreenshotCleanup()
        scheduleTrigger(reason: "Triple-click")
    }

    func mouseNotificationManager(_ manager: MouseNotificationManager, didStartDrag event: NSEvent) {
        isDragging = true
        // Cancel any scheduled cleanup since we're using the screenshot for drag selection
        cancelScreenshotCleanup()
        // Only capture if we don't already have a before screenshot from didReceiveSingleClick
        // This is important because didStartDrag is called AFTER the mouse has moved 3+ pixels,
        // meaning some selection might already be visible
        captureBeforeScreenshotIfNeeded(reason: "Drag start (late capture)")
    }

    func mouseNotificationManager(_ manager: MouseNotificationManager, didEndDrag event: NSEvent) {
        if isDragging {
            isDragging = false
            scheduleTrigger(reason: "Click and drag")
        }
    }

    func mouseNotificationManager(_ manager: MouseNotificationManager, didReceiveSingleClick event: NSEvent) {

        let isShiftClick = event.modifierFlags.contains(.shift)

        // For Shift+Click, keep existing before screenshot to detect selection extension
        // For regular click, capture new before screenshot for potential double/triple clicks
        if isShiftClick {
            cancelScreenshotCleanup()
            captureBeforeScreenshotIfNeeded(reason: "Shift+Click (late capture)")
            scheduleTrigger(reason: "Shift+Click")
        } else {
            captureBeforeScreenshot(reason: "Single click")
            // Schedule cleanup in case this is just a simple click with no follow-up action
            scheduleScreenshotCleanup()
        }
    }
}

// MARK: - KeystrokeNotificationDelegate

extension QuickEditNonAccessibilityTriggerService: KeystrokeNotificationDelegate {

    func keystrokeNotificationManager(_ manager: KeystrokeNotificationManager, didReceiveKeystroke event: KeystrokeEvent) {
        handleKeyEvent(event)
    }
}
