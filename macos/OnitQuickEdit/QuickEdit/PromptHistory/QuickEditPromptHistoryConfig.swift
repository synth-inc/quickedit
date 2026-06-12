//
//  QuickEditPromptHistoryConfig.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import Foundation

/// Configuration for the QuickEdit prompt history feature
struct QuickEditPromptHistoryConfig {

    // MARK: - Storage Limits

    /// Maximum number of prompts stored in the database
    static let maxStoredPrompts: Int = 1000

    /// Maximum number of suggestions displayed in the dropdown
    static let maxDisplayedSuggestions: Int = 5

    // MARK: - Search Configuration

    /// Minimum number of characters required to trigger a search
    static let minCharactersForSearch: Int = 1

    // MARK: - Display Configuration

    /// Maximum number of lines displayed per prompt (truncated with "...")
    static let maxPromptDisplayLines: Int = 2

    /// Estimated height per row in the prompt history list
    static let rowHeight: CGFloat = 34

    /// Maximum height for the prompt history list
    static var maxHeight: CGFloat {
        CGFloat(maxDisplayedSuggestions) * rowHeight + 8
    }

    // MARK: - Scoring Weights

    /// Weight for fuzzy match score (higher = fuzzy relevance matters more)
    static let fuzzyMatchWeight: Double = 1.0

    /// Weight for usage frequency (higher = frequently used prompts rank higher)
    static let frequencyWeight: Double = 0.3

    /// Weight for recency (higher = recently used prompts rank higher)
    static let recencyWeight: Double = 0.2

    /// Bonus points when the prompt was used in the same app
    static let appMatchBonus: Double = 0.5

    // MARK: - Recency Calculation

    /// Number of days after which recency score becomes zero
    static let recencyDaysThreshold: Double = 30.0
}
