//
//  RegionVisualization.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit
@testable import OnitQuickEdit

enum RegionVisualization {
    
    /// Draw detected regions on an image and save as PNG.
    @MainActor
    static func drawRegionsAndSaveImage(
        regions: [ImageDifferenceRegion],
        beforeImage: CGImage,
        afterImage: CGImage,
        outputDir: URL,
        key: PairKey,
        saveTiles: Bool
    ) async {
        let nsImage = NSImage(cgImage: afterImage, size: NSSize(width: afterImage.width, height: afterImage.height))
        let size = nsImage.size

        // Create the regions and tiles directories
        let regionsDir = outputDir.appendingPathComponent("regions")
        let tilesDir = regionsDir.appendingPathComponent("changed_tiles")
        try? FileManager.default.createDirectory(at: regionsDir, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(at: tilesDir, withIntermediateDirectories: true, attributes: nil)

        // Save the overall image with the regions drawn
        let regionsUrl = regionsDir.appendingPathComponent("\(key.folder).png")
        do {
            try ImageTestHelpers.drawAndSavePNG(nsImage: nsImage, size: size, to: regionsUrl) { _ in
                // Draw changed regions in transparent red
                let transparentRed = NSColor.red.withAlphaComponent(0.3)
                transparentRed.set()
                for region in regions {
                    let rect = region.rect
                    let path = NSBezierPath(rect: rect)
                    path.lineWidth = 2.0
                    path.stroke()
                }
            }
            print("RegionVisualization - Saved debug image to \(regionsUrl.path) with \(regions.count) region(s)")
        } catch {
            print("RegionVisualization - Failed to write debug image to \(regionsUrl.path): \(error)")
        }
        
        // Save individual tiles if requested
        if saveTiles {
            for (index, region) in regions.enumerated() {
                // Convert rect to CGRect with proper origin (flipping y-coordinate back)
                let flippedY = CGFloat(afterImage.height) - region.rect.origin.y - region.rect.size.height
                let cropRect = CGRect(
                    x: region.rect.origin.x,
                    y: flippedY,
                    width: region.rect.size.width,
                    height: region.rect.size.height
                )
                
                // Ensure the crop rect is within bounds
                let boundedRect = cropRect.intersection(CGRect(x: 0, y: 0, width: afterImage.width, height: afterImage.height))
                
                if boundedRect.width > 0 && boundedRect.height > 0,
                   let croppedImage = afterImage.cropping(to: boundedRect) {
                    let tileUrl = tilesDir.appendingPathComponent("\(key.folder)_tile_\(index).png")
                    do {
                        try ImageTestHelpers.savePNG(cgImage: croppedImage, to: tileUrl)
                        print("RegionVisualization - Saved tile \(index) for \(key.folder) to \(tileUrl.path)")
                    } catch {
                        print("RegionVisualization - Failed to write tile \(index) for \(key.folder): \(error)")
                    }
                }
            }
        }
    }
}

