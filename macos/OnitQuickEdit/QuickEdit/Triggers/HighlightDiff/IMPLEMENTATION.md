# Highlight Detection Model - Implementation Guide

## Overview

This model detects whether a changed region between two screenshots contains highlighted/selected text. It's designed to distinguish text selection highlighting from other UI changes.

## Model Details

| Property | Value |
|----------|-------|
| Model | HighlightDetector.mlpackage |
| Size | ~400KB |
| Input | RGB diff image (1, 3, 128, 128) |
| Output | Probability (0-1) |
| Threshold | 0.90 |
| Recall | 95.6% |
| Precision | 78.2% |
| Inference | <1ms on Apple Silicon |

## Files

```
export/
├── HighlightDetector.mlpackage/  # CoreML model for Swift/macOS
├── model-004.pt                   # PyTorch weights (if needed)
├── inference.py                   # Python inference module
└── IMPLEMENTATION.md              # This file
```

---

## Swift Integration (macOS)

### 1. Add the Model to Your Xcode Project

Drag `HighlightDetector.mlpackage` into your Xcode project. Xcode will automatically generate a Swift class for it.

### 2. Import CoreML and Vision

```swift
import CoreML
import Vision
import AppKit
```

### 3. Preprocessing Helper

```swift
class HighlightDetector {
    private let model: VNCoreMLModel
    private let threshold: Float = 0.90

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Use GPU when available

        let mlModel = try HighlightDetector(configuration: config).model
        self.model = try VNCoreMLModel(for: mlModel)
    }

    /// Preprocess before/after images into RGB diff tensor
    func preprocessImages(before: NSImage, after: NSImage) -> MLMultiArray? {
        let size = 128

        // Resize images with padding
        guard let beforeResized = resizeWithPadding(image: before, targetSize: size),
              let afterResized = resizeWithPadding(image: after, targetSize: size) else {
            return nil
        }

        // Get pixel data
        guard let beforePixels = getPixelData(from: beforeResized),
              let afterPixels = getPixelData(from: afterResized) else {
            return nil
        }

        // Create MLMultiArray for diff (1, 3, 128, 128)
        guard let diffArray = try? MLMultiArray(shape: [1, 3, 128, 128] as [NSNumber], dataType: .float32) else {
            return nil
        }

        // Compute RGB diff: (after - before), normalized to [-1, 1]
        for y in 0..<size {
            for x in 0..<size {
                let idx = y * size + x
                for c in 0..<3 {
                    let beforeVal = Float(beforePixels[idx * 4 + c]) / 255.0
                    let afterVal = Float(afterPixels[idx * 4 + c]) / 255.0
                    let diff = afterVal - beforeVal

                    let arrayIdx = c * size * size + y * size + x
                    diffArray[arrayIdx] = NSNumber(value: diff)
                }
            }
        }

        return diffArray
    }

    /// Resize image with padding to preserve aspect ratio
    func resizeWithPadding(image: NSImage, targetSize: Int) -> NSImage? {
        let originalSize = image.size
        let scale = CGFloat(targetSize) / max(originalSize.width, originalSize.height)
        let newWidth = Int(originalSize.width * scale)
        let newHeight = Int(originalSize.height * scale)

        let newImage = NSImage(size: NSSize(width: targetSize, height: targetSize))
        newImage.lockFocus()

        // Fill with gray (128, 128, 128)
        NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).setFill()
        NSRect(x: 0, y: 0, width: targetSize, height: targetSize).fill()

        // Draw image centered
        let x = (targetSize - newWidth) / 2
        let y = (targetSize - newHeight) / 2
        image.draw(in: NSRect(x: x, y: y, width: newWidth, height: newHeight),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }

    /// Extract pixel data from NSImage
    func getPixelData(from image: NSImage) -> [UInt8]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: width * 4,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    /// Detect if region contains highlighted text
    func detectHighlight(before: NSImage, after: NSImage) -> (isHighlight: Bool, probability: Float)? {
        guard let diffArray = preprocessImages(before: before, after: after) else {
            return nil
        }

        // Run inference
        do {
            let input = HighlightDetectorInput(diff_image: diffArray)
            let output = try model.prediction(from: input)

            guard let probability = output.featureValue(for: "highlight_probability")?.multiArrayValue?[0].floatValue else {
                return nil
            }

            return (probability >= threshold, probability)
        } catch {
            print("Inference error: \(error)")
            return nil
        }
    }
}
```

### 4. Usage Example

```swift
// Initialize detector (do once)
let detector = try! HighlightDetector()

// Check a region
let beforeImage: NSImage = // ... crop from before screenshot
let afterImage: NSImage = // ... crop from after screenshot

if let result = detector.detectHighlight(before: beforeImage, after: afterImage) {
    if result.isHighlight {
        print("Highlighted text detected! Confidence: \(result.probability)")
    } else {
        print("No highlight. Confidence: \(result.probability)")
    }
}
```

### 5. Alternative: Direct MLModel Usage (Simpler)

```swift
import CoreML

// Load model
let config = MLModelConfiguration()
config.computeUnits = .all
let model = try! HighlightDetector(configuration: config)

// Create input (assumes you have diffArray as MLMultiArray)
let input = HighlightDetectorInput(diff_image: diffArray)

// Run inference
let output = try! model.prediction(input: input)
let probability = output.highlight_probability[0].floatValue

let isHighlight = probability >= 0.90
```

---

## Input Preprocessing Summary

1. **Convert both images to RGB**
2. **Resize with padding** to 128x128 (preserve aspect ratio, gray padding)
3. **Normalize** pixel values to [0, 1]
4. **Compute diff**: `after - before` (result range: [-1, 1])
5. **Format as tensor**: Shape (1, 3, 128, 128) in CHW format

---

## Threshold Tuning

| Threshold | Recall | Precision | Use Case |
|-----------|--------|-----------|----------|
| 0.15 | ~98% | ~65% | Catch almost all highlights, more false alarms |
| 0.30 | ~95% | ~78% | Balanced, good recall |
| 0.50 | ~90% | ~85% | Fewer false alarms, may miss some highlights |
| 0.70 | ~80% | ~90% | High precision, lower recall |
| **0.90** | ~70% | ~95% | **Very high precision (recommended)** |

---

## Performance

- **Model size**: ~400KB
- **Inference**: <1ms on Apple Silicon GPU
- **Memory**: Minimal footprint
- **Batch processing**: Supported (adjust input shape)

---

## Troubleshooting

### Model not found
Ensure `HighlightDetector.mlpackage` is added to your Xcode target's "Copy Bundle Resources" build phase.

### Wrong predictions
- Verify preprocessing matches exactly (RGB diff, [-1,1] range, CHW format)
- Check that images are cropped to the changed region only
- Verify images are in RGB format (not grayscale or RGBA with premultiplied alpha)

### Slow inference
- Ensure `computeUnits = .all` to enable GPU
- For batch processing, use larger batch sizes
