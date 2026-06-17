//
//  CustomPrompt.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import Foundation
import GRDB

/// Represents a user-defined custom prompt for QuickEdit
struct CustomPrompt: Codable, Identifiable, Sendable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Display name (e.g., "Improve", "Translate")
    var name: String

    /// The prompt text sent to the AI
    var prompt: String

    /// SF Symbol name for the icon (default: "wand.and.sparkles.inverse")
    var icon: String

    /// Display order (lower = higher priority)
    var order: Int

    /// Bundle IDs of apps where this prompt is available (empty = global)
    var apps: [String]

    /// Encoded keyboard shortcut data (optional, must be unique)
    var shortcutData: Data?

    /// Whether the prompt is enabled/visible
    var isEnabled: Bool

    /// Creation timestamp
    let createdAt: Date

    /// Last modification timestamp
    var updatedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        icon: String = "wand.and.sparkles.inverse",
        order: Int,
        apps: [String] = [],
        shortcutData: Data? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.order = order
        self.apps = apps
        self.shortcutData = shortcutData
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Built-in Prompt

    /// The built-in "Improve" prompt ID (fixed for consistency)
    static let builtInImproveID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Creates the default built-in "Improve" prompt
    @MainActor
    static func builtInImprove(order: Int = 0, shortcutData: Data? = nil) -> CustomPrompt {
        CustomPrompt(
            id: builtInImproveID,
            name: String.localized("Improve", table: "QuickEdit"),
            prompt: """
                Improve the selected text while keeping my original voice and intent.
                - Fix spelling, grammar, and clarity issues
                - Make it more concise and easier to read without removing important details
                - Preserve personal touches, casual phrasing, and a friendly but professional tone
                - Do not sound robotic, overly polished, or like AI-written text
                - Avoid common AI tells (for example: em dashes, generic transitions, or corporate fluff)
                Style guidance:
                - Casual, direct, and human
                - Professional but approachable
                - Confident, not salesy
                Context awareness:
                - If the text is UI, website, or product copy, optimize it to be clear, compelling, and user-focused
                - If it's a message or note, prioritize natural flow and authenticity
                Output rules:
                - Do not add new information
                - Do not change the meaning
                - Return only the improved text
                Punctuation rules:
                - Do not use em dashes or dash-based sentence breaks of any kind
                - Rewrite sentences that would normally use an em dash using commas, periods, or parentheses instead
                - If an em dash appears in the input, remove it in the output
                """,
            icon: "wand.and.sparkles.inverse",
            order: order,
            apps: [],
            shortcutData: shortcutData,
            isEnabled: true
        )
    }
    
    // MARK: - Translation Prompts
    
    /// Fixed ID for the "Translate to Source Language" prompt - `Defaults[.translationSourceLanguageCode]`
    static let translationSourceID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// Fixed ID for the "Translate to Target Language" prompt - `Defaults[.translationTargetLanguageCode]`
    static let translationTargetID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    
    @MainActor
    static func createCustomTranslationPrompt(
        customPromptId: UUID,
        languageCode: String,
        order: Int
    ) -> CustomPrompt {
        let englishLocale = Locale(identifier: "en")
        let languageName = LanguageHelpers.getLanguageCodeDisplayName(for: languageCode, locale: englishLocale)

        return CustomPrompt(
            id: customPromptId,
            name: String.localized("To %@", table: "QuickEdit", languageName),
            prompt: "Translate this text directly to native \(languageName). Output only the translation with no explanations, notes, or comments. Ignore the application the text came from.",
            icon: "globe",
            order: order,
            apps: [],
            shortcutData: nil,
            isEnabled: true
        )
    }

    // MARK: - Helpers

    @MainActor
    var localizedName: String {
        if id == CustomPrompt.builtInImproveID {
            return String.localized("Improve", table: "QuickEdit")
        }
        return name
    }

    /// Whether this prompt is app-specific (not global)
    var isAppSpecific: Bool {
        !apps.isEmpty
    }
    
    /// These are for prompts that are automatically created by the app. They shouldn't be user-editable or deletable, as it can lead to confusing UX.
    var isSystemManaged: Bool {
        id == CustomPrompt.translationSourceID ||
        id == CustomPrompt.translationTargetID
    }

    /// Whether this prompt matches the given app bundle ID
    func matchesApp(_ bundleID: String?) -> Bool {
        guard let bundleID = bundleID else {
            return apps.isEmpty
        }
        return apps.isEmpty || apps.contains(bundleID)
    }

    /// Returns a formatted shortcut text string (e.g., "⌥⌘I") for display
    /// Must be called from MainActor context
    @MainActor
    var shortcutText: String? {
        guard let shortcutData = shortcutData,
              let shortcut = CustomPromptManager.shared.decodeShortcut(shortcutData)?.native
        else {
            return nil
        }

        var result = ""
        if shortcut.modifiers.contains(.option) { result += "\u{2325}" } // ⌥
        if shortcut.modifiers.contains(.control) { result += "\u{2303}" } // ⌃
        if shortcut.modifiers.contains(.command) { result += "\u{2318}" } // ⌘
        if shortcut.modifiers.contains(.shift) { result += "\u{21E7}" } // ⇧

        result += String(shortcut.key.character).uppercased()

        return result.isEmpty ? nil : result
    }

    /// Creates or updates a CustomPrompt from form data
    /// - Parameters:
    ///   - existingPrompt: The existing prompt if editing, nil if creating
    ///   - name: The prompt name
    ///   - promptText: The prompt text
    ///   - icon: The SF Symbol icon name
    ///   - apps: The selected app bundle IDs
    ///   - shortcutData: The encoded keyboard shortcut data
    /// - Returns: A new CustomPrompt instance
    @MainActor
    static func fromFormData(
        existingPrompt: CustomPrompt?,
        name: String,
        promptText: String,
        icon: String,
        apps: [String],
        shortcutData: Data?
    ) -> CustomPrompt {
        CustomPrompt(
            id: existingPrompt?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            prompt: promptText.trimmingCharacters(in: .whitespaces),
            icon: icon,
            order: existingPrompt?.order ?? CustomPromptManager.shared.nextOrder(),
            apps: apps,
            shortcutData: shortcutData,
            isEnabled: existingPrompt?.isEnabled ?? true,
            createdAt: existingPrompt?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - GRDB Extensions

extension CustomPrompt: FetchableRecord, PersistableRecord {
    static let databaseTableName = "custom_prompts"

    enum Columns: String, ColumnExpression {
        case id
        case name
        case prompt
        case icon
        case order
        case apps
        case shortcutData
        case isEnabled
        case createdAt
        case updatedAt
    }

    init(row: Row) throws {
        id = try UUID(uuidString: row[Columns.id]) ?? UUID()
        name = row[Columns.name]
        prompt = row[Columns.prompt]
        icon = row[Columns.icon]
        order = row[Columns.order]

        // Decode apps from JSON
        let appsString: String = row[Columns.apps]
        if let appsData = appsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: appsData)
        {
            apps = decoded
        } else {
            apps = []
        }

        shortcutData = row[Columns.shortcutData]
        isEnabled = row[Columns.isEnabled]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.name] = name
        container[Columns.prompt] = prompt
        container[Columns.icon] = icon
        container[Columns.order] = order

        // Encode apps to JSON
        if let appsData = try? JSONEncoder().encode(apps),
           let appsString = String(data: appsData, encoding: .utf8)
        {
            container[Columns.apps] = appsString
        } else {
            container[Columns.apps] = "[]"
        }

        container[Columns.shortcutData] = shortcutData
        container[Columns.isEnabled] = isEnabled
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}
