//
//  ChangeRegionTests.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit
import Testing
@testable import OnitQuickEdit

/// Tests for changed region detection between image pairs.
/// This validates algorithms that identify areas of visual change for cursor detection.
struct ChangedRegionTests {
    
    private let baselineManager = BaselineManager<Baseline<RegionsResult>>(
        filename: "changed_regions_baseline.json"
    )
    
    // MARK: - Tests
    @Test("Generate or overwrite changed-regions baseline")
    @MainActor
    func changedRegionsCreateBaseline() async throws {
        guard FileManager.default.fileExists(atPath: TestImageDataset.datasetRoot().path) else {
            #expect(true, "Dataset root not found; skipping test.")
            return
        }

        let computed = try await RegionTestHelpers.computeRegionsForAllPairs(
             tileSize: 96,
             tileOverlapX: 8,
             tileOverlayY: 32,
             sampleStride: 1,
             pixelDiffThreshold: 24,
             tileChangeRatioThreshold: 0.003,
             shouldWriteOverlays: true
 //            maxPairs: 50
         )

        // Uncomment to save baseline:
        // let baseline = Baseline(version: 1, results: computed)
        // try baselineManager.write(baseline)

        #expect(!computed.isEmpty, "No image pairs found while generating changed-regions baseline.")
    }


    @Test("Create changed-regions baseline for text-input-data")
    @MainActor
    func createChangedRegionTileImagesForApp() async throws {
        let appName = "Xcode"  // Options: Cursor, Slack, Notion, iTerm2, TextEdit, Xcode
        let saveTiles = true
        let changedTileThreshold = 5
        let tileSize = 96
        let tileOverlapX = 6
        let tileOverlapY = 32
              
        let datasetRoot = TestImageDataset.textInputDatasetRoot()
        guard FileManager.default.fileExists(atPath: datasetRoot.path) else {
            #expect(true, "Text input dataset not found; skipping test.")
            return
        }
        
        let validPairs = try parseTextInputDataset(appName: appName, datasetRoot: datasetRoot)
        print("ChangedRegionTests: Found \(validPairs.count) valid image pairs for app '\(appName)'.")
        
        // Process each pair
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputDir = TestImageDataset.outputsRoot()
            .appendingPathComponent("\(appName)_\(timestamp)", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        var results: [PairKey: RegionsResult] = [:]
        
        for (pairKey, prevURL, currURL) in validPairs {
            let before = try TestImageDataset.loadCGImage(prevURL)
            let after = try TestImageDataset.loadCGImage(currURL)
            
            do {
                let (regions, _, timeTaken) = try ImageDifferenceDetector.computeChangedRegions(
                    before: before,
                    after: after,
                    tileSize: tileSize,
                    tileOverlapX: tileOverlapX,
                    tileOverlapY: tileOverlapY,
                    sampleStride: 1,
                    pixelDiffThreshold: 24,
                    tileChangeRatioThreshold: 0.003 // This is around 30 pixels (i.e. the 2x15 caret) in a 96x96 image (9216 pixels total.)
                )
                
                let normalized = RegionTestHelpers.normalizeRegions(regions)
                results[pairKey] = RegionsResult(regions: normalized, timeTaken: timeTaken)
                
                if regions.count < changedTileThreshold {
                    await RegionVisualization.drawRegionsAndSaveImage(
                        regions: regions,
                        beforeImage: before,
                        afterImage: after,
                        outputDir: outputDir,
                        key: pairKey,
                        saveTiles: saveTiles
                    )
                }
            } catch {
                print("ChangedRegionTests: Error processing pair \(pairKey.folder): \(error)")
            }
        }
        
        print("ChangedRegionTests: Processed \(results.count) pairs for app '\(appName)'.")
        #expect(!results.isEmpty, "No valid image pairs found for text input dataset.")
    }
    
    /// Parse text input dataset and return valid pairs for a specific app.
    private func parseTextInputDataset(appName: String, datasetRoot: URL) throws -> [(PairKey, URL, URL)] {
        guard var files = try? FileManager.default.contentsOfDirectory(at: datasetRoot, includingPropertiesForKeys: nil) else {
            throw NSError(domain: "ChangedRegionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read text input dataset directory"])
        }
        
        struct FileInfo {
            let url: URL
            let appName: String
            let timestamp: String
            let suffix: String
        }
        
        // Uncomment to run for only recent files.
//        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
//        let recentFiles = files.filter { url in
//            if let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
//               let modDate = attrs.contentModificationDate {
//                return modDate > oneDayAgo
//            }
//            return false
//        }
//        files = recentFiles
        
        // Parse filenames: input_{AppName}_{Timestamp}_{suffix}.png
        var fileInfos: [FileInfo] = []
        for file in files {
            let filename = file.lastPathComponent
            guard filename.hasPrefix("input_") && filename.hasSuffix(".png") else { continue }
            
            let nameWithoutPrefix = String(filename.dropFirst(6))
            let nameWithoutSuffix = String(nameWithoutPrefix.dropLast(4))
            let components = nameWithoutSuffix.components(separatedBy: "_")
            guard components.count >= 3 else { continue }
            
            let parsedAppName = components[0]
            let suffix = components[components.count - 1]
            let timestamp = components[1..<(components.count - 1)].joined(separator: "_")
            
            fileInfos.append(FileInfo(url: file, appName: parsedAppName, timestamp: timestamp, suffix: suffix))
        }
        
        // Filter and group by timestamp
        let filteredFiles = fileInfos.filter { $0.appName == appName }
        var pairsByTimestamp: [String: (previous: URL?, fullwindow: URL?)] = [:]
        for fileInfo in filteredFiles {
            if fileInfo.suffix == "previous" {
                pairsByTimestamp[fileInfo.timestamp, default: (nil, nil)].previous = fileInfo.url
            } else if fileInfo.suffix == "fullwindow" {
                pairsByTimestamp[fileInfo.timestamp, default: (nil, nil)].fullwindow = fileInfo.url
            }
        }
        
        // Create pairs
        var validPairs: [(PairKey, URL, URL)] = []
        for (timestamp, urls) in pairsByTimestamp {
            if let previous = urls.previous, let fullwindow = urls.fullwindow {
                validPairs.append((PairKey(folder: timestamp), previous, fullwindow))
            }
        }
        validPairs.sort { $0.0.folder < $1.0.folder }
        
        return validPairs
    }


    @Test("Compare current changed-regions results to baseline")
    @MainActor
    func compareChangedRegionsToBaseline() async throws {
        guard FileManager.default.fileExists(atPath: TestImageDataset.datasetRoot().path) else {
            #expect(true, "Dataset root not found; skipping test.")
            return
        }
        
        let computed = try await RegionTestHelpers.computeRegionsForAllPairs(
            tileSize: 96,
            tileOverlapX: 8,
            tileOverlayY: 32,
            sampleStride: 1,
            pixelDiffThreshold: 24,
            tileChangeRatioThreshold: 0.003,
            shouldWriteOverlays: true,
            maxPairs: 15
        )
        let baseline = try baselineManager.read()

        var successCount = 0
        var failureCount = 0

        for (key, computedResult) in computed {
            if let baselineResult = baseline.results[key] {
                if computedResult == baselineResult {
                    successCount += 1
                } else {
                    failureCount += 1
                    print("Mismatch for key '\(key.folder)':\n  Baseline: \(baselineResult)\n  Computed: \(computedResult)")
                }
            } else {
                failureCount += 1
                print("Missing baseline result for key '\(key.folder)'")
            }
        }

        let extraComputed = Set(computed.keys).subtracting(baseline.results.keys)
        if !extraComputed.isEmpty {
            print("Warning: Extra computed results not in baseline: \(extraComputed)")
        }

        #expect(failureCount == 0, "There were \(failureCount) mismatches in changed-regions results (\(successCount) successes).")
    }
}

