//
//  QuickEditConversationHistoryManager.swift
//  Onit
//
//  Created by Loyd Kim on 12/26/25.
//

import Foundation
import GRDB

enum QuickEditConversationHistoryError: Error, LocalizedError {
    case databaseNotInitialized
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Conversation history database is not initialized."
        case .emptyResponse:
            return "Cannot save conversation with empty AI response."
        }
    }
}

final class QuickEditConversationHistoryManager: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton
    
    @MainActor
    static let shared = QuickEditConversationHistoryManager()
    
    // MARK: - Database
    
    private var dbQueue: DatabaseQueue?
    private let dbFile: String = "quickedit_conversation_history.sqlite"
    
    private var dbDirectoryURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Onit")
    }

    private var dbPath: String? {
        self.dbDirectoryURL?.appendingPathComponent(self.dbFile).path
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Published Properties

    @Published var conversations: [QuickEditConversationHistoryEntry]? = nil
    @Published var hasMoreHistory: Bool = false

    /// Source of truth for navigation state.
    @Published var currentConversationId: Int64? = nil

    // MARK: - Public Variables
    
    var isNavigatingHistory: Bool {
        self.currentConversationId != nil
    }

    var currentConversationIndex: Int? {
        guard let currentConversationId = self.currentConversationId,
              let currentConversations = self.conversations
        else {
            return nil
        }

        return currentConversations.firstIndex { $0.id == currentConversationId }
    }

    // MARK: - Private Variables

    private let maxAllowedStoredConversations: Int = 500
    private let pageSize: Int = 10
    
    // MARK: - History Loading

    @MainActor
    func loadConversationHistory() async {
        do {
            let conversations = try await self.fetchConversations(
                offset: 0,
                limit: self.pageSize
            )
            self.conversations = conversations
            self.hasMoreHistory = conversations.count >= self.pageSize
        } catch {
            log.error("[QuickEditConversationHistory] Failed to load history: \(error)")
            self.conversations = []
            self.hasMoreHistory = false
        }
    }

    @MainActor
    func loadMoreHistory() async {
        guard self.hasMoreHistory,
              let currentConversations = self.conversations
        else {
            return
        }

        do {
            let moreConversations = try await self.fetchConversations(
                offset: currentConversations.count,
                limit: self.pageSize
            )
            self.conversations = currentConversations + moreConversations
            self.hasMoreHistory = moreConversations.count >= self.pageSize
        } catch {
            log.error("[QuickEditConversationHistory] Failed to load more history: \(error)")
        }
    }

    // MARK: - History Navigation

    @MainActor
    @discardableResult
    func startNavigation() -> QuickEditConversationHistoryEntry? {
        guard let currentConversations = self.conversations,
              let firstConversation = currentConversations.first,
              let firstConversationId = firstConversation.id
        else {
            return nil
        }

        self.currentConversationId = firstConversationId
        return firstConversation
    }
    
    @MainActor
    @discardableResult
    func navigateToPreviousConversation() async -> QuickEditConversationHistoryEntry? {
        guard let currentConversations = self.conversations,
              let currentConversationIndex = self.currentConversationIndex,
              currentConversationIndex + 1 < currentConversations.count
        else {
            return nil
        }

        let newCurrentConversationIndex = currentConversationIndex + 1
        let newCurrentConversation = currentConversations[newCurrentConversationIndex]
        self.currentConversationId = newCurrentConversation.id

        // Load more conversations when approaching the end of the list
        if self.hasMoreHistory && newCurrentConversationIndex >= currentConversations.count - 2 {
            await self.loadMoreHistory()
        }

        return newCurrentConversation
    }

    @MainActor
    @discardableResult
    func navigateToNextConversation() -> QuickEditConversationHistoryEntry? {
        guard let currentConversations = self.conversations,
              let currentConversationIndex = self.currentConversationIndex,
              currentConversationIndex > 0
        else {
            return nil
        }

        let newCurrentConversationIndex = currentConversationIndex - 1
        let newCurrentConversation = currentConversations[newCurrentConversationIndex]
        self.currentConversationId = newCurrentConversation.id
        return newCurrentConversation
    }
    
    @MainActor
    func exitNavigation() {
        self.currentConversationId = nil
    }
    
    // MARK: - CRUD Functions

    nonisolated func fetchConversations(
        offset: Int = 0,
        limit: Int = 10
    ) async throws -> [QuickEditConversationHistoryEntry] {
        guard let dbQueue = self.dbQueue
        else {
            throw QuickEditConversationHistoryError.databaseNotInitialized
        }

        return try await dbQueue.read { db in
            try QuickEditConversationHistoryEntry
                .order(QuickEditConversationHistoryEntry.Columns.createdAt.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    nonisolated func createConversation(
        mode: QuickEditMode,
        appName: String?,
        selectedText: String,
        userInstruction: String?,
        aiResponse: String,
        globalSnapshotsJSON: String?
    ) async throws {
        guard let dbQueue = self.dbQueue
        else {
            throw QuickEditConversationHistoryError.databaseNotInitialized
        }

        guard !aiResponse.isEmpty else {
            throw QuickEditConversationHistoryError.emptyResponse
        }

        try await dbQueue.write { db in
            var newHistoryEntry = QuickEditConversationHistoryEntry(
                mode: mode,
                appName: appName,
                selectedText: selectedText,
                userInstruction: userInstruction,
                aiResponse: aiResponse,
                globalSnapshotsJSON: globalSnapshotsJSON
            )

            try newHistoryEntry.insert(db)
            try self.enforceStorageLimit(db)
        }
    }
    
    nonisolated func updateConversation(
        conversationId: Int64,
        userInstruction: String?,
        aiResponse: String,
        globalSnapshotsJSON: String?
    ) async throws {
        guard let dbQueue = self.dbQueue
        else {
            throw QuickEditConversationHistoryError.databaseNotInitialized
        }

        guard !aiResponse.isEmpty
        else {
            throw QuickEditConversationHistoryError.emptyResponse
        }

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE \(QuickEditConversationHistoryEntry.databaseTableName)
                    SET userInstruction = ?, aiResponse = ?, globalSnapshotsJSON = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [userInstruction, aiResponse, globalSnapshotsJSON, Date(), conversationId]
            )
        }
    }
    
    @MainActor
    func createOrUpdateConversation(
        conversationId: Int64?,
        mode: QuickEditMode,
        appName: String?,
        selectedText: String,
        userInstruction: String?,
        aiResponse: String,
        globalSnapshotsJSON: String?
    ) async throws {
        if let conversationId = conversationId {
            try await self.updateConversation(
                conversationId: conversationId,
                userInstruction: userInstruction,
                aiResponse: aiResponse,
                globalSnapshotsJSON: globalSnapshotsJSON
            )
        } else {
            try await self.createConversation(
                mode: mode,
                appName: appName,
                selectedText: selectedText,
                userInstruction: userInstruction,
                aiResponse: aiResponse,
                globalSnapshotsJSON: globalSnapshotsJSON
            )
        }

        /// Reload conversation history to most recent version.
        await self.loadConversationHistory()

        if self.currentConversationId == nil,
           let mostRecentConversation = self.conversations?.first
        {
            self.currentConversationId = mostRecentConversation.id
        }
    }
    
    // MARK: - Private Functions
    
    private func setupDatabase() {
        guard let dbDirectoryURL = self.dbDirectoryURL,
              let dbPath = self.dbPath
        else {
            log.error("[QuickEditConversationHistory] Could not determine database path")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: dbDirectoryURL,
                withIntermediateDirectories: true
            )

            self.dbQueue = try DatabaseQueue(path: dbPath)

            try self.dbQueue?.write { db in
                try self.createTables(in: db)
                try self.createIndexes(in: db)
            }
        } catch {
            log.error("[QuickEditConversationHistory] Database setup failed: \(error)")
        }
    }
    
    private func createTables(in db: Database) throws {
        try db.create(
            table: QuickEditConversationHistoryEntry.databaseTableName,
            ifNotExists: true
        ) { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("mode", .text).notNull()
            table.column("appName", .text)
            table.column("selectedText", .text).notNull()
            table.column("userInstruction", .text)
            table.column("aiResponse", .text).notNull()
            table.column("globalSnapshotsJSON", .text)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
    }
    
    private func createIndexes(in db: Database) throws {
        try db.create(
            index: "idx_conversation_appName",
            on: QuickEditConversationHistoryEntry.databaseTableName,
            columns: ["appName"],
            ifNotExists: true
        )
        
        try db.create(
            index: "idx_conversation_createdAt",
            on: QuickEditConversationHistoryEntry.databaseTableName,
            columns: ["createdAt"],
            ifNotExists: true
        )
    }
    
    private func enforceStorageLimit(_ db: Database) throws {
        let count = try QuickEditConversationHistoryEntry.fetchCount(db)

        guard count > self.maxAllowedStoredConversations else { return }

        let excess = count - self.maxAllowedStoredConversations

        try db.execute(
            sql: """
                DELETE FROM \(QuickEditConversationHistoryEntry.databaseTableName)
                WHERE id IN (
                    SELECT id FROM \(QuickEditConversationHistoryEntry.databaseTableName)
                    ORDER BY createdAt ASC
                    LIMIT ?
                )
                """,
            arguments: [excess]
        )
    }
}
