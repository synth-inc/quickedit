//
//  NonAXTriggerLabelingView.swift
//  Onit
//
//  Debug UI for labeling non-accessibility trigger test cases.
//

#if DEBUG || ONIT_BETA
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct NonAXTriggerLabelingView: View {
    let capture: NonAXTriggerDebugCapture
    let onDismiss: () -> Void

    @State private var containsHighlight: Bool? = true
    @State private var selectedRegionIndices: Set<Int> = []
    @State private var showSideBySide: Bool = false
    @State private var showMLDebug: Bool = false
    @State private var saveError: String? = nil
    @State private var saveSuccess: Bool = false

    private var canSave: Bool {
        guard let containsHighlight else { return false }
        if containsHighlight {
            return !selectedRegionIndices.isEmpty
        }
        return true
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Non-AX Trigger Test Case Labeling")
                    .font(.headline)
                Spacer()
            }

            // Image display
            if showSideBySide {
                HStack(spacing: 8) {
                    ScrollableImageView(
                        image: capture.beforeImage,
                        label: "Before",
                        showOverlays: false,
                        capture: capture,
                        selectedRegionIndices: $selectedRegionIndices,
                        containsHighlight: containsHighlight
                    )
                    ScrollableImageView(
                        image: capture.afterImage,
                        label: "After",
                        showOverlays: true,
                        capture: capture,
                        selectedRegionIndices: $selectedRegionIndices,
                        containsHighlight: containsHighlight
                    )
                }
            } else {
                ScrollableImageView(
                    image: capture.afterImage,
                    label: "After",
                    showOverlays: true,
                    capture: capture,
                    selectedRegionIndices: $selectedRegionIndices,
                    containsHighlight: containsHighlight
                )
            }

            // Controls
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show side-by-side with Before image", isOn: $showSideBySide)

                Button("Show ML Debug Info") {
                    showMLDebug = true
                }
                .buttonStyle(.bordered)

                Divider()

                // Contains highlight question
                Text("Does this image contain highlighted text?")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 16) {
                    RadioButton(label: "Yes", isSelected: containsHighlight == true) {
                        containsHighlight = true
                    }
                    RadioButton(label: "No", isSelected: containsHighlight == false) {
                        containsHighlight = false
                        selectedRegionIndices.removeAll()
                    }
                }

                if containsHighlight == true {
                    Text("Select all regions that containing highlighted text (click again to deselect)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    if selectedRegionIndices.isEmpty {
                        Text("No regions selected")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        let sortedIndices = selectedRegionIndices.sorted().map { "Region \($0 + 1)" }.joined(separator: ", ")
                        Text("Selected: \(sortedIndices)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if let error = saveError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if saveSuccess {
                    Text("Test case saved successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            Divider()

            // Buttons
            HStack {
                Text("Pinch to zoom, scroll to pan")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save Test Case") {
                    saveTestCase()
                }
                .disabled(!canSave)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showMLDebug) {
            MLDebugPanel(capture: capture)
        }
    }

    // MARK: - Save Test Case

    private func saveTestCase() {
        saveError = nil
        saveSuccess = false

        guard let containsHighlight else { return }

        let fileManager = FileManager.default

        // Use a temp directory for saving files before uploading to Azure
        // This avoids permission issues in external beta builds
        let tempDir = fileManager.temporaryDirectory
        let caseDirName = "case_\(Int(Date().timeIntervalSince1970 * 1000))"
        let caseDir = tempDir.appendingPathComponent("non-ax-trigger-\(caseDirName)")

        do {
            try fileManager.createDirectory(at: caseDir, withIntermediateDirectories: true)
        } catch {
            saveError = "Failed to create temp directory: \(error.localizedDescription)"
            return
        }

        let beforeURL = caseDir.appendingPathComponent("before.png")
        if !saveImage(capture.beforeImage, to: beforeURL) {
            saveError = "Failed to save before.png"
            return
        }

        let afterURL = caseDir.appendingPathComponent("after.png")
        if !saveImage(capture.afterImage, to: afterURL) {
            saveError = "Failed to save after.png"
            return
        }

        let metadata = TestCaseMetadata(
            containsHighlight: containsHighlight,
            selectedRegionIndices: selectedRegionIndices.sorted(),
            regions: capture.changedRegions.map { RegionRect(x: $0.origin.x, y: $0.origin.y, width: $0.width, height: $0.height) },
            mouseLocation: PointData(x: capture.mouseLocation.x, y: capture.mouseLocation.y),
            accountEmail: AuthManager.shared.account?.email
        )

        let metadataURL = caseDir.appendingPathComponent("metadata.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            saveError = "Failed to save metadata: \(error.localizedDescription)"
            return
        }

        saveSuccess = true
        print("[NonAXTriggerLabeling] Saved test case to temp: \(caseDir.path)")

        // Upload to Azure and clean up temp files when done
        Task {
            await NonAXTriggerDatasetUploader.shared.uploadCase(from: caseDir, caseName: caseDirName)
            // Clean up temp directory after upload
            try? fileManager.removeItem(at: caseDir)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onDismiss()
        }
    }

    private func saveImage(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

}

// MARK: - ML Debug Panel

private struct MLDebugPanel: View {
    let capture: NonAXTriggerDebugCapture
    @Environment(\.dismiss) private var dismiss
    @State private var results: [HighlightDetectionDebugResult] = []
    @State private var selectedResult: HighlightDetectionDebugResult?
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ML Model Results")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(results.filter { $0.isHighlight }.count)/\(results.count) detected as highlights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Analyzing regions...")
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text("No regions to analyze")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                // Full-width scrollable list of regions, sorted by probability (highest first)
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        let sortedResults = results.enumerated().sorted { $0.element.probability > $1.element.probability }
                        ForEach(sortedResults, id: \.offset) { index, result in
                            MLRegionDebugRow(index: index, result: result, selectedResult: $selectedResult)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500, maxHeight: 700)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(item: $selectedResult) { result in
            MLRegionZoomView(result: result)
        }
        .task {
            await loadResultsAsync()
        }
    }

    /// Loads ML detection results asynchronously to keep the UI responsive.
    /// Uses Swift's structured concurrency to allow UI updates between operations.
    @MainActor
    private func loadResultsAsync() async {
        isLoading = true

        // Yield to allow the loading UI to render before starting heavy work
        await Task.yield()

        // Call the ML service (thread-safe, can run from any context)
        results = HighlightDetectorService.shared.detectHighlightsWithDebugInfo(
            beforeImage: capture.beforeImage,
            afterImage: capture.afterImage,
            regions: capture.changedRegions
        )

        isLoading = false
    }
}

// MARK: - ML Region Debug Row (Full Width)

private struct MLRegionDebugRow: View {
    let index: Int
    let result: HighlightDetectionDebugResult
    @Binding var selectedResult: HighlightDetectionDebugResult?

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            VStack(spacing: 4) {
                Text(result.isHighlight ? "✅" : "❌")
                    .font(.title2)
                Text("Region \(index + 1)")
                    .font(.caption.weight(.medium))
            }
            .frame(width: 70)

            // Before image
            VStack(spacing: 2) {
                Text("Before")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Image(nsImage: NSImage(cgImage: result.beforeCrop, size: NSSize(width: result.beforeCrop.width, height: result.beforeCrop.height)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
            }
            .frame(maxWidth: .infinity)

            // After image
            VStack(spacing: 2) {
                Text("After")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Image(nsImage: NSImage(cgImage: result.afterCrop, size: NSSize(width: result.afterCrop.width, height: result.afterCrop.height)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
            }
            .frame(maxWidth: .infinity)

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("P: \(String(format: "%.2f", result.probability))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(result.isHighlight ? .green : .red)
                Text("Threshold: 0.90")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("\(Int(result.region.width))×\(Int(result.region.height)) px")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button("Zoom") {
                    selectedResult = result
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .frame(width: 100)
        }
        .padding(10)
        .background(result.isHighlight ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.isHighlight ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            selectedResult = result
        }
    }
}

// MARK: - ML Region Zoom View (Sheet)

private struct MLRegionZoomView: View {
    let result: HighlightDetectionDebugResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Region Detail")
                    .font(.headline)
                Spacer()
                Text(result.isHighlight ? "✅ Highlight" : "❌ Not Highlight")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(result.isHighlight ? .green : .red)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal)

            // Stats bar
            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Text("Probability:")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", result.probability))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundColor(result.isHighlight ? .green : .red)
                }
                HStack(spacing: 4) {
                    Text("Threshold:")
                        .foregroundColor(.secondary)
                    Text("0.90")
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Text("Size:")
                        .foregroundColor(.secondary)
                    Text("\(Int(result.region.width))×\(Int(result.region.height)) px")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .font(.subheadline)
            .padding(.horizontal)

            // Zoomable images side by side
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Before")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    ZoomableImageView(image: result.beforeCrop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                }

                VStack(spacing: 4) {
                    Text("After")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    ZoomableImageView(image: result.afterCrop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            Text("Pinch to zoom, scroll to pan")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Zoomable Image View

private struct ZoomableImageView: NSViewRepresentable {
    typealias NSViewType = NSScrollView

    let image: CGImage

    func makeNSView(context: NSViewRepresentableContext<ZoomableImageView>) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        // Allow magnification with pinch gesture
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 20.0

        let imageView = NSImageView()
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView.imageScaling = .scaleProportionallyUpOrDown

        scrollView.documentView = imageView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: NSViewRepresentableContext<ZoomableImageView>) {
        if let imageView = scrollView.documentView as? NSImageView {
            imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

            // Size the image view to fill the scroll view initially
            if let clipView = scrollView.contentView as? NSClipView {
                imageView.frame = clipView.bounds
            }
        }
    }
}

// MARK: - Identifiable conformance for sheet

extension HighlightDetectionDebugResult: Identifiable {
    var id: String {
        "\(region.origin.x)-\(region.origin.y)-\(region.width)-\(region.height)"
    }
}

// MARK: - Scrollable Image View

private struct ScrollableImageView: View {
    let image: CGImage
    let label: String
    let showOverlays: Bool
    let capture: NonAXTriggerDebugCapture
    @Binding var selectedRegionIndices: Set<Int>
    let containsHighlight: Bool?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ImageScrollView(
                    image: image,
                    showOverlays: showOverlays,
                    capture: capture,
                    selectedRegionIndices: $selectedRegionIndices,
                    containsHighlight: containsHighlight,
                    containerSize: geometry.size
                )
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - NSScrollView Wrapper

private struct ImageScrollView: NSViewRepresentable {
    typealias NSViewType = NSScrollView

    let image: CGImage
    let showOverlays: Bool
    let capture: NonAXTriggerDebugCapture
    @Binding var selectedRegionIndices: Set<Int>
    let containsHighlight: Bool?
    let containerSize: CGSize

    func makeNSView(context: NSViewRepresentableContext<ImageScrollView>) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        // Allow magnification with pinch gesture
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 10.0

        // Create the content view
        let contentView = ImageContentView(
            image: image,
            showOverlays: showOverlays,
            capture: capture,
            selectedRegionIndices: $selectedRegionIndices,
            containsHighlight: containsHighlight
        )
        contentView.frame = NSRect(origin: .zero, size: containerSize)

        scrollView.documentView = contentView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: NSViewRepresentableContext<ImageScrollView>) {
        // Update content view size based on magnification
        if let contentView = scrollView.documentView as? ImageContentView {
            let scaledSize = NSSize(
                width: containerSize.width * scrollView.magnification,
                height: containerSize.height * scrollView.magnification
            )
            if contentView.frame.size != scaledSize {
                contentView.frame.size = scaledSize
                contentView.needsDisplay = true
            }
            contentView.updateBindings(selectedRegionIndices: $selectedRegionIndices, containsHighlight: containsHighlight)
        }
    }
}

// MARK: - Image Content View (NSView)

private class ImageContentView: NSView {
    let cgImage: CGImage
    let showOverlays: Bool
    let capture: NonAXTriggerDebugCapture
    private var selectedRegionIndices: Binding<Set<Int>>
    private var containsHighlight: Bool?

    init(image: CGImage, showOverlays: Bool, capture: NonAXTriggerDebugCapture, selectedRegionIndices: Binding<Set<Int>>, containsHighlight: Bool?) {
        self.cgImage = image
        self.showOverlays = showOverlays
        self.capture = capture
        self.selectedRegionIndices = selectedRegionIndices
        self.containsHighlight = containsHighlight
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBindings(selectedRegionIndices: Binding<Set<Int>>, containsHighlight: Bool?) {
        self.selectedRegionIndices = selectedRegionIndices
        self.containsHighlight = containsHighlight
        needsDisplay = true
    }

    /// Calculate the aspect-fit rect for drawing the image within the view bounds
    private func calculateDrawRect() -> CGRect {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let viewSize = bounds.size

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            // Image is wider - fit to width
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // Image is taller - fit to height
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let drawRect = calculateDrawRect()

        // Draw image using NSImage to handle orientation correctly
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        nsImage.draw(in: drawRect)

        // Draw overlays if enabled
        if showOverlays {
            let scaleFactor = drawRect.width / CGFloat(cgImage.width)

            for (index, region) in capture.changedRegions.enumerated() {
                let isSelected = selectedRegionIndices.wrappedValue.contains(index)

                // Convert region coordinates to view coordinates
                let scaledX = drawRect.origin.x + region.origin.x * scaleFactor
                let scaledY = drawRect.origin.y + region.origin.y * scaleFactor
                let scaledWidth = region.width * scaleFactor
                let scaledHeight = region.height * scaleFactor

                let overlayRect = CGRect(x: scaledX, y: scaledY, width: scaledWidth, height: scaledHeight)

                // Draw fill
                let fillColor = isSelected ? NSColor.green.withAlphaComponent(0.4) : NSColor.blue.withAlphaComponent(0.3)
                fillColor.setFill()
                NSBezierPath(rect: overlayRect).fill()

                // Draw border
                let borderColor = isSelected ? NSColor.green : NSColor.blue
                borderColor.setStroke()
                let path = NSBezierPath(rect: overlayRect)
                path.lineWidth = isSelected ? 3 : 1
                path.stroke()
            }

            // Draw crosshair at mouse location
            let mouseX = drawRect.origin.x + capture.mouseLocation.x * scaleFactor
            let mouseY = drawRect.origin.y + capture.mouseLocation.y * scaleFactor
            let crosshairSize: CGFloat = 20

            NSColor.red.setStroke()
            let horizontalPath = NSBezierPath()
            horizontalPath.move(to: NSPoint(x: mouseX - crosshairSize/2, y: mouseY))
            horizontalPath.line(to: NSPoint(x: mouseX + crosshairSize/2, y: mouseY))
            horizontalPath.lineWidth = 2
            horizontalPath.stroke()

            let verticalPath = NSBezierPath()
            verticalPath.move(to: NSPoint(x: mouseX, y: mouseY - crosshairSize/2))
            verticalPath.line(to: NSPoint(x: mouseX, y: mouseY + crosshairSize/2))
            verticalPath.lineWidth = 2
            verticalPath.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard showOverlays, containsHighlight == true else {
            super.mouseDown(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let drawRect = calculateDrawRect()
        let scaleFactor = drawRect.width / CGFloat(cgImage.width)

        // Check if click is within any region
        for (index, region) in capture.changedRegions.enumerated() {
            let scaledX = drawRect.origin.x + region.origin.x * scaleFactor
            let scaledY = drawRect.origin.y + region.origin.y * scaleFactor
            let scaledWidth = region.width * scaleFactor
            let scaledHeight = region.height * scaleFactor

            let overlayRect = CGRect(x: scaledX, y: scaledY, width: scaledWidth, height: scaledHeight)

            if overlayRect.contains(location) {
                if selectedRegionIndices.wrappedValue.contains(index) {
                    selectedRegionIndices.wrappedValue.remove(index)
                } else {
                    selectedRegionIndices.wrappedValue.insert(index)
                }
                needsDisplay = true
                return
            }
        }

        super.mouseDown(with: event)
    }
}

// MARK: - Supporting Views

private struct RadioButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .strokeBorder(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                    .background(Circle().fill(isSelected ? Color.blue : Color.clear))
                    .frame(width: 16, height: 16)
                Text(label)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Models

private struct TestCaseMetadata: Codable {
    let containsHighlight: Bool
    let selectedRegionIndices: [Int]
    let regions: [RegionRect]
    let mouseLocation: PointData
    let accountEmail: String?

    enum CodingKeys: String, CodingKey {
        case containsHighlight = "contains_highlight"
        case selectedRegionIndices = "selected_region_indices"
        case regions
        case mouseLocation = "mouse_location"
        case accountEmail = "account_email"
    }
}

private struct RegionRect: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private struct PointData: Codable {
    let x: CGFloat
    let y: CGFloat
}
#endif
