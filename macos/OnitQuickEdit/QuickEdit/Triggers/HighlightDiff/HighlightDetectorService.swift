//
//  HighlightDetectorService.swift
//  Onit
//
//  ML-based service for detecting whether a changed region contains highlighted text.
//  Uses a CoreML model trained on before/after screenshot pairs.
//

import CoreML
import CoreGraphics
import Foundation

/// Debug result containing cropped images and ML prediction
struct HighlightDetectionDebugResult {
    let region: CGRect
    let beforeCrop: CGImage
    let afterCrop: CGImage
    let probability: Float
    let isHighlight: Bool
}

/// Service for detecting highlighted text regions using ML
/// Thread-safe: the model is loaded once during init and only read thereafter.
final class HighlightDetectorService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = HighlightDetectorService()

    // MARK: - Properties

    /// CoreML model, set once during init and read-only thereafter (thread-safe)
    private let model: HighlightDetector?
    private let targetSize = 128
    private let threshold: Float = 0.90

    // MARK: - Initialization

    private init() {
        var loadedModel: HighlightDetector?
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use GPU when available
            loadedModel = try HighlightDetector(configuration: config)
            print("[HighlightDetector] Model loaded successfully")
        } catch {
            print("[HighlightDetector] Failed to load model: \(error)")
        }
        self.model = loadedModel
    }

    // MARK: - Public Methods

    /// Detect if a region contains highlighted text
    /// - Parameters:
    ///   - beforeImage: Full screenshot before selection
    ///   - afterImage: Full screenshot after selection
    ///   - region: The changed region to analyze (in image coordinates)
    /// - Returns: Tuple of (isHighlight, probability) or nil if detection fails
    func detectHighlight(
        beforeImage: CGImage,
        afterImage: CGImage,
        region: CGRect
    ) -> (isHighlight: Bool, probability: Float)? {
        guard let model = model else {
            print("[HighlightDetector] Model not loaded")
            return nil
        }

        // Crop the region from both images
        guard let beforeCrop = cropRegion(from: beforeImage, region: region),
              let afterCrop = cropRegion(from: afterImage, region: region) else {
            print("[HighlightDetector] Failed to crop region")
            return nil
        }

        // Preprocess into diff tensor
        guard let diffArray = preprocessImages(before: beforeCrop, after: afterCrop) else {
            print("[HighlightDetector] Failed to preprocess images")
            return nil
        }

        // Run inference
        do {
            let input = HighlightDetectorInput(diff_image: diffArray)
            let output = try model.prediction(input: input)
            let probability = output.highlight_probability[0].floatValue

            return (probability >= threshold, probability)
        } catch {
            print("[HighlightDetector] Inference error: \(error)")
            return nil
        }
    }

    /// Batch detect highlights for multiple regions
    /// - Parameters:
    ///   - beforeImage: Full screenshot before selection
    ///   - afterImage: Full screenshot after selection
    ///   - regions: Array of changed regions to analyze
    /// - Returns: Array of regions that contain highlighted text, along with their probabilities
    func detectHighlights(
        beforeImage: CGImage,
        afterImage: CGImage,
        regions: [CGRect]
    ) -> [(region: CGRect, probability: Float)] {
        var results: [(region: CGRect, probability: Float)] = []

        for region in regions {
            if let result = detectHighlight(beforeImage: beforeImage, afterImage: afterImage, region: region) {
                if result.isHighlight {
                    results.append((region, result.probability))
                    print("[HighlightDetector] ✅ Region \(Int(region.width))x\(Int(region.height)) | probability: \(String(format: "%.2f", result.probability)) >= \(threshold) (highlight)")
                } else {
                    print("[HighlightDetector] ❌ Region \(Int(region.width))x\(Int(region.height)) | probability: \(String(format: "%.2f", result.probability)) < \(threshold) (not highlight)")
                }
            } else {
                print("[HighlightDetector] ⚠️ Region \(Int(region.width))x\(Int(region.height)) | inference failed")
            }
        }

        return results
    }

    /// Debug method that returns cropped images along with predictions for visualization
    /// - Parameters:
    ///   - beforeImage: Full screenshot before selection
    ///   - afterImage: Full screenshot after selection
    ///   - regions: Array of changed regions to analyze
    /// - Returns: Array of debug results with cropped images and predictions
    func detectHighlightsWithDebugInfo(
        beforeImage: CGImage,
        afterImage: CGImage,
        regions: [CGRect]
    ) -> [HighlightDetectionDebugResult] {
        var results: [HighlightDetectionDebugResult] = []

        for region in regions {
            guard let beforeCrop = cropRegion(from: beforeImage, region: region),
                  let afterCrop = cropRegion(from: afterImage, region: region) else {
                continue
            }

            // Use the already cropped images to avoid double cropping
            if let result = detectHighlightFromCrops(beforeCrop: beforeCrop, afterCrop: afterCrop) {
                results.append(HighlightDetectionDebugResult(
                    region: region,
                    beforeCrop: beforeCrop,
                    afterCrop: afterCrop,
                    probability: result.probability,
                    isHighlight: result.isHighlight
                ))
            }
        }

        return results
    }

    // MARK: - Internal Methods

    /// Detect highlight from pre-cropped images (avoids double cropping)
    private func detectHighlightFromCrops(
        beforeCrop: CGImage,
        afterCrop: CGImage
    ) -> (isHighlight: Bool, probability: Float)? {
        guard let model = model else {
            print("[HighlightDetector] Model not loaded")
            return nil
        }

        // Preprocess into diff tensor
        guard let diffArray = preprocessImages(before: beforeCrop, after: afterCrop) else {
            print("[HighlightDetector] Failed to preprocess images")
            return nil
        }

        // Run inference
        do {
            let input = HighlightDetectorInput(diff_image: diffArray)
            let output = try model.prediction(input: input)
            let probability = output.highlight_probability[0].floatValue

            return (probability >= threshold, probability)
        } catch {
            print("[HighlightDetector] Inference error: \(error)")
            return nil
        }
    }

    // MARK: - Private Methods

    /// Crop a region from a CGImage
    /// Note: Regions use bottom-left origin (Y=0 at bottom), but CGImage uses top-left origin (Y=0 at top)
    private func cropRegion(from image: CGImage, region: CGRect) -> CGImage? {
        let imageHeight = CGFloat(image.height)

        // Flip Y coordinate: convert from bottom-left origin to top-left origin
        let flippedY = imageHeight - region.maxY
        let flippedRegion = CGRect(
            x: region.origin.x,
            y: flippedY,
            width: region.width,
            height: region.height
        )

        // Ensure region is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clampedRegion = flippedRegion.intersection(imageRect)

        guard !clampedRegion.isEmpty else { return nil }

        return image.cropping(to: clampedRegion)
    }

    /// Preprocess before/after images into RGB diff tensor
    private func preprocessImages(before: CGImage, after: CGImage) -> MLMultiArray? {
        // Resize images with padding to target size
        guard let beforeResized = resizeWithPadding(image: before),
              let afterResized = resizeWithPadding(image: after) else {
            return nil
        }

        // Get pixel data
        guard let beforePixels = getPixelData(from: beforeResized),
              let afterPixels = getPixelData(from: afterResized) else {
            return nil
        }

        // Create MLMultiArray for diff (1, 3, 128, 128)
        guard let diffArray = try? MLMultiArray(shape: [1, 3, NSNumber(value: targetSize), NSNumber(value: targetSize)], dataType: .float32) else {
            return nil
        }

        // Compute RGB diff: (after - before), normalized to [-1, 1]
        // Pixel data is in BGRA format (premultipliedFirst + byteOrder32Little)
        for y in 0..<targetSize {
            for x in 0..<targetSize {
                let idx = y * targetSize + x
                let pixelOffset = idx * 4

                // BGRA format: B=0, G=1, R=2, A=3
                let beforeR = Float(beforePixels[pixelOffset + 2]) / 255.0
                let beforeG = Float(beforePixels[pixelOffset + 1]) / 255.0
                let beforeB = Float(beforePixels[pixelOffset + 0]) / 255.0

                let afterR = Float(afterPixels[pixelOffset + 2]) / 255.0
                let afterG = Float(afterPixels[pixelOffset + 1]) / 255.0
                let afterB = Float(afterPixels[pixelOffset + 0]) / 255.0

                // Compute diff (range: [-1, 1])
                let diffR = afterR - beforeR
                let diffG = afterG - beforeG
                let diffB = afterB - beforeB

                // Store in CHW format: channel * H * W + y * W + x
                let rIdx = 0 * targetSize * targetSize + y * targetSize + x
                let gIdx = 1 * targetSize * targetSize + y * targetSize + x
                let bIdx = 2 * targetSize * targetSize + y * targetSize + x

                diffArray[rIdx] = NSNumber(value: diffR)
                diffArray[gIdx] = NSNumber(value: diffG)
                diffArray[bIdx] = NSNumber(value: diffB)
            }
        }

        return diffArray
    }

    /// Resize image with padding to preserve aspect ratio
    private func resizeWithPadding(image: CGImage) -> CGImage? {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)
        let targetSizeF = CGFloat(targetSize)

        // Calculate scale to fit within target size
        let scale = targetSizeF / max(originalWidth, originalHeight)
        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

        // Calculate centering offset
        let offsetX = (targetSize - newWidth) / 2
        let offsetY = (targetSize - newHeight) / 2

        // Create context with gray background (128, 128, 128)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        // Fill with gray background
        context.setFillColor(CGColor(gray: 0.5, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        // Draw image centered
        context.draw(image, in: CGRect(x: offsetX, y: offsetY, width: newWidth, height: newHeight))

        return context.makeImage()
    }

    /// Extract pixel data from CGImage
    private func getPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }
}
