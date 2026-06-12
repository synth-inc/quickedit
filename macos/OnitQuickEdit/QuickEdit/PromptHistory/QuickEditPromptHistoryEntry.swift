//
//  QuickEditPromptHistoryEntry.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import Foundation
import GRDB

/// Represents a prompt entry in the history database
struct QuickEditPromptHistoryEntry: Codable, Identifiable, Sendable {
    /// Unique identifier (auto-incremented by the database)
    let id: Int64?

    /// The prompt text content
    let text: String

    /// Name of the application where the prompt was used
    let appName: String?

    /// Number of times this prompt has been validated
    var usageCount: Int

    /// Date when the prompt was last used
    var lastUsedAt: Date

    /// Date when the prompt was first created
    let createdAt: Date

    // MARK: - Initialization

    init(
        id: Int64? = nil,
        text: String,
        appName: String? = nil,
        usageCount: Int = 1,
        lastUsedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.appName = appName
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

// MARK: - GRDB Extensions

extension QuickEditPromptHistoryEntry: FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_history"

    enum Columns: String, ColumnExpression {
        case id
        case text
        case appName
        case usageCount
        case lastUsedAt
        case createdAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        text = row[Columns.text]
        appName = row[Columns.appName]
        usageCount = row[Columns.usageCount]
        lastUsedAt = row[Columns.lastUsedAt]
        createdAt = row[Columns.createdAt]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.text] = text
        container[Columns.appName] = appName
        container[Columns.usageCount] = usageCount
        container[Columns.lastUsedAt] = lastUsedAt
        container[Columns.createdAt] = createdAt
    }
}

// MARK: - Scored Entry (for search results)

/// A prompt entry with an associated relevance score for display
struct ScoredPromptHistoryEntry: Identifiable {
    let entry: QuickEditPromptHistoryEntry
    let score: Double

    var id: Int64? { entry.id }
    var text: String { entry.text }
    var appName: String? { entry.appName }
    var usageCount: Int { entry.usageCount }
    var lastUsedAt: Date { entry.lastUsedAt }
}
