//
//  RegionTestHelpers.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit
@testable import OnitQuickEdit

enum RegionTestHelpers {
    
    /// Normalize regions into a deterministic, sorted format for comparison.
    static func normalizeRegions(_ regions: [ImageDifferenceRegion]) -> [RegionRect] {
        // Sort deterministically top-to-bottom, then left-to-right, then by size
        func key(_ r: ImageDifferenceRegion) -> (Int, Int, Int, Int) {
            let x = Int(r.rect.origin.x.rounded())
            let y = Int(r.rect.origin.y.rounded())
            let w = Int(r.rect.size.width.rounded())
            let h = Int(r.rect.size.height.rounded())
            return (y, x, w, h)
        }
        let sorted = regions.sorted { a, b in
            let ka = key(a)
            let kb = key(b)
            if ka.0 != kb.0 { return ka.0 < kb.0 }
            if ka.1 != kb.1 { return ka.1 < kb.1 }
            if ka.2 != kb.2 { return ka.2 < kb.2 }
            return ka.3 < kb.3
        }
        return sorted.map { r in
            // Round changedRatio to stabilize encoding
            let roundedRatio = (r.changedRatio * 1000).rounded() / 1000
            return RegionRect(
                x: Int(r.rect.origin.x.rounded()),
                y: Int(r.rect.origin.y.rounded()),
                width: Int(r.rect.size.width.rounded()),
                height: Int(r.rect.size.height.rounded()),
                changedRatio: roundedRatio
            )
        }
    }
    
    /// Compute changed regions for all image pairs in the test dataset.
    static func computeRegionsForAllPairs(
        tileSize: Int = 96,
        tileOverlapX: Int = 8,
        tileOverlayY: Int = 32,
        sampleStride: Int = 1,
        pixelDiffThreshold: UInt8 = 24,
        tileChangeRatioThreshold: Double = 0.003,
        shouldWriteOverlays: Bool = false,
        saveTiles: Bool = false,
        maxPairs: Int? = nil
    ) async throws -> [PairKey: RegionsResult] {
        let pairs = try TestImageDataset.enumeratePairs()
        print("RegionTestHelpers: Found \(pairs.count) image pairs.")
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputDir = TestImageDataset.outputsRoot().appendingPathComponent("\(timestamp)", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        var results: [PairKey: RegionsResult] = [:]
        var processedCount = 0
        for (pairKey, prevURL, currURL) in pairs {
            if let maxPairs = maxPairs, processedCount >= maxPairs {
                break
            }
            let before = try TestImageDataset.loadCGImage(prevURL)
            let after = try TestImageDataset.loadCGImage(currURL)
            
            do {
                let (regions, _, timeTaken) = try ImageDifferenceDetector.computeChangedRegions(
                    before: before,
                    after: after,
                    tileSize: tileSize,
                    tileOverlapX: 8,
                    tileOverlapY: 32,
                    sampleStride: sampleStride,
                    pixelDiffThreshold: pixelDiffThreshold,
                    tileChangeRatioThreshold: tileChangeRatioThreshold
                )
                
                let normalized = normalizeRegions(regions)
                results[pairKey] = RegionsResult(regions: normalized, timeTaken: timeTaken)
                
                if shouldWriteOverlays {
                    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
                    // Skip drawing for images with more than 5 regions (debug optimization)
                    if regions.count <= 5 {
                        await RegionVisualization.drawRegionsAndSaveImage(
                            regions: regions,
                            beforeImage: before,
                            afterImage: after,
                            outputDir: outputDir,
                            key: pairKey,
                            saveTiles: saveTiles
                        )
                    } else {
                        print("RegionTestHelpers: Skipping drawing for \(pairKey.folder) (has \(regions.count) regions, limit is 5)")
                    }
                }
            } catch {
                print("RegionTestHelpers: Error processing pair \(pairKey.folder): \(error)")
            }
            processedCount += 1
        }
        return results
    }
}

