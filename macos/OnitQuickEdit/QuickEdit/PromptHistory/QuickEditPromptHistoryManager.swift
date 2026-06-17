//
//  QuickEditPromptHistoryManager.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import Foundation
import GRDB

/// Manages the QuickEdit prompt history database
final class QuickEditPromptHistoryManager: ObservableObject, @unchecked Sendable {

    // MARK: - Singleton

    @MainActor
    static let shared = QuickEditPromptHistoryManager()

    // MARK: - Database

    private var dbQueue: DatabaseQueue?
    private let dbFile: String = "quickedit_prompt_history.sqlite"

    private var dbPath: String? {
        let fileManager = FileManager.default

        guard let applicationSupportURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else {
            return nil
        }

        let onitURL = applicationSupportURL.appendingPathComponent("Onit")
        try? fileManager.createDirectory(at: onitURL, withIntermediateDirectories: true)

        return onitURL.appendingPathComponent(dbFile).path
    }

    // MARK: - Initialization

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        guard let dbPath = dbPath else {
            log.error("[QuickEditPromptHistory] Could not determine database path")
            return
        }

        do {
            dbQueue = try DatabaseQueue(path: dbPath)

            try dbQueue?.write { db in
                try createTables(in: db)
                try createIndexes(in: db)
            }

        } catch {
            log.error("[QuickEditPromptHistory] Database setup failed: \(error)")
        }
    }

    private func createTables(in db: Database) throws {
        try db.create(table: QuickEditPromptHistoryEntry.databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("text", .text).notNull()
            t.column("appName", .text)
            t.column("usageCount", .integer).notNull().defaults(to: 1)
            t.column("lastUsedAt", .datetime).notNull()
            t.column("createdAt", .datetime).notNull()
        }
    }

    private func createIndexes(in db: Database) throws {
        // Index for text search
        try db.create(
            index: "idx_prompt_text",
            on: QuickEditPromptHistoryEntry.databaseTableName,
            columns: ["text"],
            ifNotExists: true
        )

        // Index for app filtering/boost
        try db.create(
            index: "idx_prompt_app",
            on: QuickEditPromptHistoryEntry.databaseTableName,
            columns: ["appName"],
            ifNotExists: true
        )

        // Composite index for sorting (usageCount DESC, lastUsedAt DESC)
        try db.create(
            index: "idx_prompt_usage",
            on: QuickEditPromptHistoryEntry.databaseTableName,
            columns: ["usageCount", "lastUsedAt"],
            ifNotExists: true
        )
    }

    // MARK: - CRUD Operations

    /// Saves or updates a prompt in the history
    /// - Parameters:
    ///   - text: The prompt text
    ///   - appName: The name of the application
    nonisolated func savePrompt(
        text: String,
        appName: String?
    ) async {
        guard let dbQueue = dbQueue else { return }

        // Trim and normalize the text
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        do {
            try await dbQueue.write { db in
                // Check if the prompt already exists (case-insensitive)
                if var existingEntry = try QuickEditPromptHistoryEntry
                    .filter(QuickEditPromptHistoryEntry.Columns.text.lowercased == normalizedText.lowercased())
                    .fetchOne(db) {
                    // Update existing entry
                    existingEntry.usageCount += 1
                    existingEntry.lastUsedAt = Date()
                    try existingEntry.update(db)
                } else {
                    // Create new entry
                    let newEntry = QuickEditPromptHistoryEntry(
                        text: normalizedText,
                        appName: appName
                    )
                    try newEntry.insert(db)

                    // Check and enforce storage limit
                    try self.enforceStorageLimit(db)
                }
            }
        } catch {
            log.error("[QuickEditPromptHistory] Failed to save prompt: \(error)")
        }
    }

    /// Deletes a prompt from the history
    /// - Parameter id: The ID of the prompt to delete
    nonisolated func deletePrompt(id: Int64) async {
        guard let dbQueue = dbQueue else { return }

        do {
            try await dbQueue.write { db in
                try QuickEditPromptHistoryEntry
                    .filter(QuickEditPromptHistoryEntry.Columns.id == id)
                    .deleteAll(db)
            }
        } catch {
            log.error("[QuickEditPromptHistory] Failed to delete prompt: \(error)")
        }
    }

    /// Fetches all prompts from the database
    /// - Parameter limit: Maximum number of prompts to fetch
    /// - Returns: Array of prompt history entries
    nonisolated func fetchAllPrompts(limit: Int = QuickEditPromptHistoryConfig.maxStoredPrompts) async -> [QuickEditPromptHistoryEntry] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try await dbQueue.read { db in
                try QuickEditPromptHistoryEntry
                    .order(
                        QuickEditPromptHistoryEntry.Columns.usageCount.desc,
                        QuickEditPromptHistoryEntry.Columns.lastUsedAt.desc
                    )
                    .limit(limit)
                    .fetchAll(db)
            }
        } catch {
            log.error("[QuickEditPromptHistory] Failed to fetch prompts: \(error)")
            return []
        }
    }

    /// Searches prompts using fuzzy matching
    /// - Parameters:
    ///   - query: The search query
    ///   - currentAppName: The current app's name for app match bonus
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of scored prompt entries, sorted by relevance
    nonisolated func searchPrompts(
        query: String,
        currentAppName: String?,
        limit: Int = QuickEditPromptHistoryConfig.maxDisplayedSuggestions
    ) async -> [ScoredPromptHistoryEntry] {
        let allPrompts = await fetchAllPrompts()

        // If query is empty, return recent prompts
        if query.isEmpty {
            return allPrompts.prefix(limit).map { entry in
                ScoredPromptHistoryEntry(entry: entry, score: 1.0)
            }
        }

        // Use FuzzyMatcher to score and sort entries
        let scoredEntries = FuzzyMatcher.scoreEntries(
            pattern: query,
            entries: allPrompts,
            currentAppName: currentAppName
        )

        // Return top results
        return Array(scoredEntries.prefix(limit))
    }

    /// Clears all prompts from the history
    nonisolated func clearAllPrompts() async {
        guard let dbQueue = dbQueue else { return }

        do {
            try await dbQueue.write { db in
                try QuickEditPromptHistoryEntry.deleteAll(db)
            }
        } catch {
            log.error("[QuickEditPromptHistory] Failed to clear prompts: \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Enforces the maximum storage limit by deleting oldest/least used prompts
    private func enforceStorageLimit(_ db: Database) throws {
        let count = try QuickEditPromptHistoryEntry.fetchCount(db)
        let maxPrompts = QuickEditPromptHistoryConfig.maxStoredPrompts

        guard count > maxPrompts else { return }

        let excess = count - maxPrompts

        // Delete the oldest and least used prompts
        // Order by usageCount ASC (least used first), then by lastUsedAt ASC (oldest first)
        let promptsToDelete = try QuickEditPromptHistoryEntry
            .order(
                QuickEditPromptHistoryEntry.Columns.usageCount.asc,
                QuickEditPromptHistoryEntry.Columns.lastUsedAt.asc
            )
            .limit(excess)
            .fetchAll(db)

        for prompt in promptsToDelete {
            try prompt.delete(db)
        }

    }
}
