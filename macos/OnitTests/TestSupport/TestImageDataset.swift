//
//  TestImageDataset.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit
@testable import OnitQuickEdit

/// Shared dataset utilities for image-based tests.
enum TestImageDataset {

    static func documentsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
    }

    /// Root of the project (resolved via the path of this source file)
    /// #filePath = .../onit-beacon/macos/OnitTests/TestSupport/TestImageDataset.swift
    static var datasetsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // TestSupport/
            .deletingLastPathComponent()  // OnitTests/
            .deletingLastPathComponent()  // macos/
            .deletingLastPathComponent()  // onit-beacon/
            .appendingPathComponent("datasets")
    }

    static func datasetRoot() -> URL {
        datasetsRoot.appendingPathComponent("diff-debug-images")
    }

    static func outputsRoot() -> URL {
        documentsDirectory().appendingPathComponent("diff_debug_images_output_new", isDirectory: true)
    }

    static func textInputDatasetRoot() -> URL {
        datasetsRoot.appendingPathComponent("text-input-dataset")
    }
    
    static func enumeratePairs() throws -> [(PairKey, URL, URL)] {
        let root = datasetRoot()
        var pairs: [(PairKey, URL, URL)] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name == "previous.png" {
                let folder = url.deletingLastPathComponent()
                let current = folder.appendingPathComponent("current.png")
                if FileManager.default.fileExists(atPath: current.path) {
                    let key = PairKey(folder: folder.lastPathComponent)
                    pairs.append((key, url, current))
                }
            }
        }
        pairs.sort { $0.0.folder < $1.0.folder }
        return pairs
    }

    static func loadCGImage(_ url: URL) throws -> CGImage {
        guard let nsImage = NSImage(contentsOf: url) else {
            throw NSError(domain: "TestImageDataset", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(url.path)"])
        }
        var rect = NSRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw NSError(domain: "TestImageDataset", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage for \(url.path)"])
        }
        return cgImage
    }
}
