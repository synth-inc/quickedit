//
//  TestTypes.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation

// MARK: - Shared Types

/// Shared key for identifying an image pair folder in tests.
struct PairKey: Codable, Hashable {
    let folder: String
}

/// Generic baseline structure for test results.
struct Baseline<T: Codable & Equatable>: Codable, Equatable {
    let version: Int
    let results: [PairKey: T]
}

// MARK: - Best Integer Shift Types

struct ShiftResult: Codable, Equatable {
    let dx: Int
    let dy: Int
    let score: Double
}

// MARK: - Changed Region Types

struct RegionRect: Codable, Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let changedRatio: Double
    
    static func == (lhs: RegionRect, rhs: RegionRect) -> Bool {
        return lhs.x == rhs.x &&
               lhs.y == rhs.y &&
               lhs.width == rhs.width &&
               lhs.height == rhs.height
        // changedRatio is intentionally ignored for equality
    }
}

struct RegionsResult: Codable, Equatable {
    let regions: [RegionRect]
    let timeTaken: Double
    
    static func == (lhs: RegionsResult, rhs: RegionsResult) -> Bool {
        // Early out if counts differ
        if lhs.regions.count != rhs.regions.count { return false }
        // For each region in lhs, try to find a matching region in rhs (order doesn't matter)
        var unmatched = rhs.regions
        for region in lhs.regions {
            if let idx = unmatched.firstIndex(where: { $0 == region }) {
                unmatched.remove(at: idx)
            } else {
                return false
            }
        }
        return unmatched.isEmpty
    }
}

