//
//  CustomPromptManager.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import Combine
import Foundation
import GRDB
import KeyboardShortcuts

/// Manages the QuickEdit custom prompts database
/// Singleton pattern following QuickEditPromptHistoryManager
final class CustomPromptManager: ObservableObject, @unchecked Sendable {

    // MARK: - Singleton

    @MainActor
    static let shared = CustomPromptManager()

    // MARK: - Published Properties

    /// All custom prompts, sorted by order
    @Published private(set) var customPrompts: [CustomPrompt] = []
    
    @Published private(set) var isReady: Bool = false

    // MARK: - Database

    private var dbQueue: DatabaseQueue?
    private let dbFile: String = "quickedit_custom_prompts.sqlite"

    private var dbPath: String? {
        let fileManager = FileManager.default

        guard let applicationSupportURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else {
            return nil
        }

        let onitURL = applicationSupportURL.appendingPathComponent("Onit")
        try? fileManager.createDirectory(at: onitURL, withIntermediateDirectories: true)

        return onitURL.appendingPathComponent(dbFile).path
    }

    // MARK: - Initialization

    private init() {
        setupDatabase()
        Task { @MainActor in
            await loadPrompts()
            await migrateBuiltInImproveIfNeeded()
            isReady = true
        }
    }

    private func setupDatabase() {
        guard let dbPath = dbPath else {
            log.error("[CustomPromptManager] Could not determine database path")
            return
        }

        do {
            dbQueue = try DatabaseQueue(path: dbPath)

            try dbQueue?.write { db in
                try createTables(in: db)
                try createIndexes(in: db)
            }

        } catch {
            log.error("[CustomPromptManager] Database setup failed: \(error)")
        }
    }

    private func createTables(in db: Database) throws {
        try db.create(table: CustomPrompt.databaseTableName, ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("prompt", .text).notNull()
            t.column("icon", .text).notNull().defaults(to: "wand.and.sparkles.inverse")
            t.column("order", .integer).notNull()
            t.column("apps", .text).notNull().defaults(to: "[]")
            t.column("shortcutData", .blob)
            t.column("isEnabled", .boolean).notNull().defaults(to: true)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }

    private func createIndexes(in db: Database) throws {
        // Index for ordering
        try db.create(
            index: "idx_custom_prompt_order",
            on: CustomPrompt.databaseTableName,
            columns: ["order"],
            ifNotExists: true
        )

        // Index for enabled status
        try db.create(
            index: "idx_custom_prompt_enabled",
            on: CustomPrompt.databaseTableName,
            columns: ["isEnabled"],
            ifNotExists: true
        )
    }

    // MARK: - Migration

    /// Migrates the built-in "Improve" prompt if not already present
    @MainActor
    private func migrateBuiltInImproveIfNeeded() async {
        guard let dbQueue = dbQueue else { return }

        do {
            let exists = try await dbQueue.read { db in
                try CustomPrompt
                    .filter(CustomPrompt.Columns.id == CustomPrompt.builtInImproveID.uuidString)
                    .fetchOne(db) != nil
            }

            if !exists {
                // Encode the existing quickEditImprove shortcut
                let shortcutData = encodeShortcut(KeyboardShortcuts.Name.quickEditImprove.shortcut)

                let improvePrompt = CustomPrompt.builtInImprove(
                    order: 0,
                    shortcutData: shortcutData
                )

                try await dbQueue.write { db in
                    try improvePrompt.insert(db)
                }

                log.info("[CustomPromptManager] Built-in 'Improve' prompt migrated successfully")

                await loadPrompts()
            }
        } catch {
            log.error("[CustomPromptManager] Failed to migrate built-in Improve: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// Loads all prompts from the database
    @MainActor
    func loadPrompts() async {
        customPrompts = await fetchAllPrompts()
    }

    /// Fetches all prompts from the database
    nonisolated func fetchAllPrompts() async -> [CustomPrompt] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try await dbQueue.read { db in
                try CustomPrompt
                    .order(CustomPrompt.Columns.order.asc)
                    .fetchAll(db)
            }
        } catch {
            log.error("[CustomPromptManager] Failed to fetch prompts: \(error)")
            return []
        }
    }

    /// Creates a new custom prompt
    /// - Parameter prompt: The prompt to create
    /// - Throws: Error if creation fails or shortcut is duplicate
    nonisolated func createPrompt(_ prompt: CustomPrompt) async throws {
        guard let dbQueue = dbQueue else {
            throw CustomPromptError.databaseNotAvailable
        }

        // Validate shortcut uniqueness
        if prompt.shortcutData != nil {
            let isDuplicate = await isShortcutDuplicate(prompt.shortcutData, excludingId: prompt.id)
            if isDuplicate {
                throw CustomPromptError.duplicateShortcut
            }
        }

        do {
            try await dbQueue.write { db in
                try prompt.insert(db)
            }

            await MainActor.run {
                Task {
                    await self.loadPrompts()
                }
            }
        } catch {
            log.error("[CustomPromptManager] Failed to create prompt: \(error)")
            throw error
        }
    }

    /// Updates an existing custom prompt
    /// - Parameter prompt: The prompt to update
    /// - Throws: Error if update fails or shortcut is duplicate
    nonisolated func updatePrompt(_ prompt: CustomPrompt) async throws {
        guard let dbQueue = dbQueue else {
            throw CustomPromptError.databaseNotAvailable
        }

        // Validate shortcut uniqueness
        if prompt.shortcutData != nil {
            let isDuplicate = await isShortcutDuplicate(prompt.shortcutData, excludingId: prompt.id)
            if isDuplicate {
                throw CustomPromptError.duplicateShortcut
            }
        }

        var updatedPrompt = prompt
        updatedPrompt.updatedAt = Date()
        let promptToSave = updatedPrompt

        do {
            try await dbQueue.write { db in
                try promptToSave.update(db)
            }

            await MainActor.run {
                Task {
                    await self.loadPrompts()
                }
            }
        } catch {
            log.error("[CustomPromptManager] Failed to update prompt: \(error)")
            throw error
        }
    }

    /// Deletes a custom prompt
    /// - Parameter id: The ID of the prompt to delete
    nonisolated func deletePrompt(id: UUID) async throws {
        guard let dbQueue = dbQueue else {
            throw CustomPromptError.databaseNotAvailable
        }

        do {
            try await dbQueue.write { db in
                try CustomPrompt
                    .filter(CustomPrompt.Columns.id == id.uuidString)
                    .deleteAll(db)
            }

            await MainActor.run {
                Task {
                    await self.loadPrompts()
                }
            }
        } catch {
            log.error("[CustomPromptManager] Failed to delete prompt: \(error)")
            throw error
        }
    }

    /// Reorders prompts based on the new order
    /// - Parameter prompts: The prompts in their new order
    nonisolated func reorderPrompts(_ prompts: [CustomPrompt]) async throws {
        guard let dbQueue = dbQueue else {
            throw CustomPromptError.databaseNotAvailable
        }

        do {
            try await dbQueue.write { db in
                for (index, var prompt) in prompts.enumerated() {
                    prompt.order = index
                    prompt.updatedAt = Date()
                    try prompt.update(db)
                }
            }

            await MainActor.run {
                Task {
                    await self.loadPrompts()
                }
            }
        } catch {
            log.error("[CustomPromptManager] Failed to reorder prompts: \(error)")
            throw error
        }
    }

    /// Toggles the enabled state of a prompt
    /// - Parameters:
    ///   - id: The ID of the prompt
    ///   - isEnabled: The new enabled state
    nonisolated func setPromptEnabled(id: UUID, isEnabled: Bool) async throws {
        guard let dbQueue = dbQueue else {
            throw CustomPromptError.databaseNotAvailable
        }

        do {
            try await dbQueue.write { db in
                if var prompt = try CustomPrompt
                    .filter(CustomPrompt.Columns.id == id.uuidString)
                    .fetchOne(db)
                {
                    prompt.isEnabled = isEnabled
                    prompt.updatedAt = Date()
                    try prompt.update(db)
                }
            }

            await MainActor.run {
                Task {
                    await self.loadPrompts()
                }
            }
        } catch {
            log.error("[CustomPromptManager] Failed to toggle prompt enabled: \(error)")
            throw error
        }
    }

    // MARK: - Query Operations

    /// Gets the default prompt for the given app
    /// Priority: app-specific prompts first (by order), then global prompts (by order)
    /// - Parameter bundleID: The bundle ID of the current app (nil for global only)
    /// - Returns: The default prompt, or nil if none available
    @MainActor
    func getDefaultPrompt(forApp bundleID: String?) -> CustomPrompt? {
        let enabled = customPrompts.filter { $0.isEnabled }

        // Priority 1: App-specific prompts (by order)
        if let bundleID = bundleID {
            let appSpecific = enabled.filter { $0.apps.contains(bundleID) }
            if let first = appSpecific.sorted(by: { $0.order < $1.order }).first {
                return first
            }
        }

        // Priority 2: Global prompts (by order)
        let global = enabled.filter { $0.apps.isEmpty }
        return global.sorted(by: { $0.order < $1.order }).first
    }

    /// Gets all enabled prompts for the given app, sorted by relevance
    /// Order: app-specific prompts first (by order), then global prompts (by order)
    /// - Parameter bundleID: The bundle ID of the current app (nil for global only)
    /// - Returns: Array of enabled prompts sorted by relevance
    @MainActor
    func getEnabledPrompts(forApp bundleID: String?) -> [CustomPrompt] {
        let enabled = customPrompts.filter { $0.isEnabled }

        var result: [CustomPrompt] = []

        // First: App-specific prompts (by order)
        if let bundleID = bundleID {
            let appSpecific = enabled
                .filter { $0.apps.contains(bundleID) }
                .sorted(by: { $0.order < $1.order })
            result.append(contentsOf: appSpecific)
        }

        // Second: Global prompts (by order)
        let global = enabled
            .filter { $0.apps.isEmpty }
            .sorted(by: { $0.order < $1.order })
        result.append(contentsOf: global)

        return result
    }

    /// Gets the next available order value
    @MainActor
    func nextOrder() -> Int {
        return (customPrompts.map { $0.order }.max() ?? -1) + 1
    }

    // MARK: - Shortcut Helpers

    /// Checks if a shortcut is already used by another prompt
    /// - Parameters:
    ///   - shortcutData: The shortcut data to check
    ///   - excludingId: ID to exclude from the check (for updates)
    /// - Returns: True if the shortcut is duplicate
    private func isShortcutDuplicate(_ shortcutData: Data?, excludingId: UUID) async -> Bool {
        guard let shortcutData = shortcutData, let dbQueue = dbQueue else {
            return false
        }

        do {
            return try await dbQueue.read { db in
                try CustomPrompt
                    .filter(CustomPrompt.Columns.shortcutData == shortcutData)
                    .filter(CustomPrompt.Columns.id != excludingId.uuidString)
                    .fetchOne(db) != nil
            }
        } catch {
            return false
        }
    }

    /// Encodes a keyboard shortcut to Data
    func encodeShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) -> Data? {
        guard let shortcut = shortcut else { return nil }
        return try? JSONEncoder().encode(shortcut)
    }

    /// Decodes a keyboard shortcut from Data
    func decodeShortcut(_ data: Data?) -> KeyboardShortcuts.Shortcut? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcuts.Shortcut.self, from: data)
    }
}

// MARK: - Errors

enum CustomPromptError: LocalizedError {
    case databaseNotAvailable
    case duplicateShortcut
    case promptNotFound

    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database is not available"
        case .duplicateShortcut:
            return "This keyboard shortcut is already used by another prompt"
        case .promptNotFound:
            return "Prompt not found"
        }
    }
}
