//
//  HighlightedTextBoundTrainingDataManager.swift
//  Onit
//
//  Created by Kévin Naudin on 06/27/2025.
//

import Foundation
import AppKit
import Defaults
import GRDB

// MARK: - Data Structures

struct HighlightedTextBoundTrainingSample: Codable, Identifiable {
    let id: Int64?
    let createdAt: Date
    let screenshotBase64: String
    let selectedText: String
    let boundingBox: NormalizedBoundingBox
    let primaryScreenFrame: ScreenFrame
    let appScreenFrame: ScreenFrame
    let appScreenMenuBarHeight: Double
    let appName: String
    let isValidated: Bool
    
    init(id: Int64? = nil,
         createdAt: Date = Date(),
         screenshotBase64: String,
         selectedText: String,
         boundingBox: NormalizedBoundingBox,
         primaryScreenFrame: ScreenFrame,
         appScreenFrame: ScreenFrame,
         appScreenMenuBarHeight: Double,
         appName: String,
         isValidated: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.screenshotBase64 = screenshotBase64
        self.selectedText = selectedText
        self.boundingBox = boundingBox
        self.primaryScreenFrame = primaryScreenFrame
        self.appScreenFrame = appScreenFrame
        self.appScreenMenuBarHeight = appScreenMenuBarHeight
        self.appName = appName
        self.isValidated = isValidated
    }
}

struct NormalizedBoundingBox: Codable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = max(0, min(1, x))
        self.y = max(0, min(1, y))
        self.width = max(0, min(1, width))
        self.height = max(0, min(1, height))
    }
}

struct ScreenFrame: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - GRDB Extensions

extension HighlightedTextBoundTrainingSample: FetchableRecord, PersistableRecord {
    static let databaseTableName = "highlighted_text_bound_training_samples"
    
    enum Columns: String, ColumnExpression {
        case id,
             createdAt,
             screenshotBase64,
             selectedText,
             boundingBox,
             primaryScreenFrame,
             appScreenFrame,
             appScreenMenuBarHeight,
             appName,
             isValidated
    }
    
    init(row: Row) throws {
        id = row[Columns.id]
        createdAt = row[Columns.createdAt]
        screenshotBase64 = row[Columns.screenshotBase64]
        selectedText = row[Columns.selectedText]
        
        let boundingBoxString: String = row[Columns.boundingBox]
        let boundingBoxData = boundingBoxString.data(using: .utf8) ?? Data()
        boundingBox = try JSONDecoder().decode(NormalizedBoundingBox.self, from: boundingBoxData)
        
        let primaryScreenFrameString: String = row[Columns.primaryScreenFrame]
        let primaryScreenFrameData = primaryScreenFrameString.data(using: .utf8) ?? Data()
        primaryScreenFrame = try JSONDecoder().decode(ScreenFrame.self, from: primaryScreenFrameData)
        
        let appScreenFrameString: String = row[Columns.appScreenFrame]
        let appScreenFrameData = appScreenFrameString.data(using: .utf8) ?? Data()
        appScreenFrame = try JSONDecoder().decode(ScreenFrame.self, from: appScreenFrameData)
        
        appScreenMenuBarHeight = row[Columns.appScreenMenuBarHeight]
        appName = row[Columns.appName]
        isValidated = row[Columns.isValidated]
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.createdAt] = createdAt
        container[Columns.screenshotBase64] = screenshotBase64
        container[Columns.selectedText] = selectedText
        
        // Encode structs to JSON strings
        let encoder = JSONEncoder()
        let boundingBoxData = try encoder.encode(boundingBox)
        container[Columns.boundingBox] = String(data: boundingBoxData, encoding: .utf8)
        
        let primaryScreenFrameData = try encoder.encode(primaryScreenFrame)
        container[Columns.primaryScreenFrame] = String(data: primaryScreenFrameData, encoding: .utf8)
        
        let appScreenFrameData = try encoder.encode(appScreenFrame)
        container[Columns.appScreenFrame] = String(data: appScreenFrameData, encoding: .utf8)
        
        container[Columns.appScreenMenuBarHeight] = appScreenMenuBarHeight
        container[Columns.appName] = appName
        container[Columns.isValidated] = isValidated
    }
}

// MARK: - Training Data Manager

@MainActor
class HighlightedTextBoundTrainingDataManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HighlightedTextBoundTrainingDataManager()
    
    // MARK: - Published Properties
    @Published var isCapturing: Bool = false
    @Published var samplesCount: Int = 0
    
    // MARK: - Properties
    private var dbQueue: DatabaseQueue?
    private let dbFile: String = HighlightedTextBoundTrainingSample.databaseTableName + ".sqlite"
    private var dbPath: String? {
        let fileManager = FileManager.default
        
        guard let applicationSupportURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else {
            log.error("Could not find Application Support directory")
            return nil
        }
        
        let onitURL = applicationSupportURL.appendingPathComponent("Onit")
        try? fileManager.createDirectory(at: onitURL, withIntermediateDirectories: true)
        
        return onitURL.appendingPathComponent(dbFile).path
    }
    
    // MARK: - Private initializer
    private init() {
        setupDatabase()
        updateSamplesCount()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        guard let dbPath = dbPath else { return }
        
        do {
            dbQueue = try DatabaseQueue(path: dbPath)
            
            try dbQueue?.write { db in
                try createTable(in: db)
            }
            
            log.info("Database initialized successfully at: \(dbPath)")
        } catch {
            log.error("Failed to setup database: \(error)")
        }
    }
    
    private func createTable(in db: Database) throws {
        try db.create(table: HighlightedTextBoundTrainingSample.databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("createdAt", .datetime).notNull()
            t.column("screenshotBase64", .text).notNull()
            t.column("selectedText", .text).notNull()
            t.column("boundingBox", .jsonText).notNull()
            t.column("primaryScreenFrame", .jsonText).notNull()
            t.column("appScreenFrame", .jsonText).notNull()
            t.column("appScreenMenuBarHeight", .double).notNull()
            t.column("appName", .text).notNull()
            t.column("isValidated", .boolean).notNull().defaults(to: false)
        }
        
        log.info("Training data table created successfully")
    }
    
    // MARK: - Public Methods

    func getUnvalidatedSamples(offset: Int = 0, limit: Int = 12) async -> [HighlightedTextBoundTrainingSample] {
        guard let dbQueue = dbQueue else { return [] }
        
        do {
            return try await dbQueue.read { db in
                try HighlightedTextBoundTrainingSample
                    .filter(HighlightedTextBoundTrainingSample.Columns.isValidated == false)
                    .order(HighlightedTextBoundTrainingSample.Columns.createdAt.desc)
                    .limit(limit, offset: offset)
                    .fetchAll(db)
            }
        } catch {
            log.error("Failed to fetch unvalidated samples: \(error)")
            return []
        }
    }
    
    func getValidatedCount() async -> Int {
        guard let dbQueue = dbQueue else { return 0 }
        
        do {
            return try await dbQueue.read { db in
                try HighlightedTextBoundTrainingSample
                    .filter(HighlightedTextBoundTrainingSample.Columns.isValidated == true)
                    .fetchCount(db)
            }
        } catch {
            log.error("Failed to get validated count: \(error)")
            return 0
        }
    }
    
    func getUnvalidatedCount() async -> Int {
        guard let dbQueue = dbQueue else { return 0 }
        
        do {
            return try await dbQueue.read { db in
                try HighlightedTextBoundTrainingSample
                    .filter(HighlightedTextBoundTrainingSample.Columns.isValidated == false)
                    .fetchCount(db)
            }
        } catch {
            log.error("Failed to get unvalidated count: \(error)")
            return 0
        }
    }
    
    func updateSample(_ sample: HighlightedTextBoundTrainingSample) async {
        guard let dbQueue = dbQueue else { return }
        
        do {
            try await dbQueue.write { db in
                try sample.update(db)
            }
            updateSamplesCount()
            log.info("Sample updated successfully")
        } catch {
            log.error("Failed to update sample: \(error)")
        }
    }
    
    func delete(sample: HighlightedTextBoundTrainingSample) async {
        guard let dbQueue = dbQueue else { return }
        
        do {
            try await dbQueue.write { db in
                try sample.delete(db)
            }
            updateSamplesCount()
            log.info("Sample deleted permanently")
        } catch {
            log.error("Failed to delete sample: \(error)")
        }
    }
    
    func getTotalCount() async -> Int {
        guard let dbQueue = dbQueue else { return 0 }
        
        do {
            return try await dbQueue.read { db in
                try HighlightedTextBoundTrainingSample.fetchCount(db)
            }
        } catch {
            log.error("Failed to get total count: \(error)")
            return 0
        }
    }
    
    // MARK: - Private Methods

    private func updateSamplesCount() {
        Task {
            let count = await getTotalCount()
            await MainActor.run {
                self.samplesCount = count
            }
        }
    }
}
