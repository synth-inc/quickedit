//
//  BaselineManager.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation

/// Generic baseline manager for reading and writing test baselines.
struct BaselineManager<T: Codable> {
    let filename: String
    
    private func baselineURL() -> URL {
        TestImageDataset.datasetRoot().appendingPathComponent(filename, isDirectory: false)
    }
    
    func read() throws -> T {
        let url = baselineURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func write(_ baseline: T) throws {
        let url = baselineURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let data = try JSONEncoder()
            .with { encoder in encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
            .encode(baseline)
        try data.write(to: url, options: .atomic)
    }
}

