//
//  QuickEditConversationHistoryEntry.swift
//  Onit
//
//  Created by Loyd Kim on 12/26/25.
//

import Foundation
import GRDB

struct QuickEditConversationHistoryEntry: Codable, Identifiable, Sendable {
    var id: Int64?

    let mode: QuickEditMode

    let appName: String?

    let selectedText: String

    let userInstruction: String?

    let aiResponse: String

    let globalSnapshotsJSON: String?

    let createdAt: Date

    let updatedAt: Date

    init(
        id: Int64? = nil,
        mode: QuickEditMode,
        appName: String? = nil,
        selectedText: String,
        userInstruction: String? = nil,
        aiResponse: String,
        globalSnapshotsJSON: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mode = mode
        self.appName = appName
        self.selectedText = selectedText
        self.userInstruction = userInstruction
        self.aiResponse = aiResponse
        self.globalSnapshotsJSON = globalSnapshotsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var globalSnapshots: [TextSnapshot]? {
        guard let json = globalSnapshotsJSON,
              let data = json.data(using: .utf8)
        else {
            return nil
        }
        
        return try? JSONDecoder().decode([TextSnapshot].self, from: data)
    }
}

// MARK: - GRDB Extensions

extension QuickEditConversationHistoryEntry: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "conversation_history"
    
    enum Columns: String, ColumnExpression {
        case id
        case mode
        case appName
        case selectedText
        case userInstruction
        case aiResponse
        case globalSnapshotsJSON
        case createdAt
        case updatedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        mode = row[Columns.mode]
        appName = row[Columns.appName]
        selectedText = row[Columns.selectedText]
        userInstruction = row[Columns.userInstruction]
        aiResponse = row[Columns.aiResponse]
        globalSnapshotsJSON = row[Columns.globalSnapshotsJSON]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.mode] = mode
        container[Columns.appName] = appName
        container[Columns.selectedText] = selectedText
        container[Columns.userInstruction] = userInstruction
        container[Columns.aiResponse] = aiResponse
        container[Columns.globalSnapshotsJSON] = globalSnapshotsJSON
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
