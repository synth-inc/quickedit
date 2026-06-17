//
//  BestIntegerShiftTests.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit
import Testing
@testable import OnitQuickEdit

/// Tests for best integer shift detection between image pairs.
/// This validates pixel-level alignment algorithms used before computing differences.
struct BestIntegerShiftTests {
    
    private let baselineManager = BaselineManager<Baseline<ShiftResult>>(
        filename: "best_integer_shift_baseline.json"
    )

    /// Compute shift results for all image pairs in the dataset.
    /// Currently returns empty results - enable implementation when needed.
    private func computeShifts() throws -> [PairKey: ShiftResult] {
        // Implementation disabled - uncomment and adapt when needed for baseline generation
        return [:]
    }

    @Test("Generate or verify best-integer-shift baseline")
    func bestIntegerShiftCreateBaseline() throws {
        guard FileManager.default.fileExists(atPath: TestImageDataset.datasetRoot().path) else {
            #expect(true, "Dataset root not found; skipping test.")
            return
        }

        let computed = try computeShifts().filter { $0.value.score <= 100 }
        let baseline = Baseline(version: 1, results: computed)

        try baselineManager.write(baseline)
        #expect(!computed.isEmpty, "No image pairs found while generating baseline.")
    }
    
    @Test("Compare the current code against the baseline")
    func compareBestIntegerShiftToBaseline() throws {
        guard FileManager.default.fileExists(atPath: TestImageDataset.datasetRoot().path) else {
            #expect(true, "Dataset root not found; skipping test.")
            return
        }
        
        // TODO: Tim - this is currently not working, it's not a priority to fix right now. 
        // We will have to reimplement the computeShifts function if we want to use this test.
        let computed = try computeShifts()
        let baseline = try baselineManager.read()
        
        var successCount = 0
        var failureCount = 0
        
        for (key, baselineResult) in baseline.results {
            if let computedResult = computed[key] {
                if computedResult.dx == baselineResult.dx && computedResult.dy == baselineResult.dy {
                    successCount += 1
                } else {
                    failureCount += 1
                    print("Mismatch for key '\(key)':\n  Baseline: \(baselineResult)\n  Computed: \(computedResult)")
                }
            } else {
                failureCount += 1
                print("Missing computed result for key '\(key)'")
            }
        }

        let extraComputedKeys = Set(computed.keys).subtracting(baseline.results.keys)
        if !extraComputedKeys.isEmpty {
            print("Warning: Extra computed results not in baseline: \(extraComputedKeys)")
        }

        #expect(failureCount == 0, "There were \(failureCount) mismatches in best-integer-shift results (\(successCount) successes).")
    }
}

