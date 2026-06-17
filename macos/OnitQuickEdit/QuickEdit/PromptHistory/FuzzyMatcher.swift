//
//  FuzzyMatcher.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import Foundation

/// Fuzzy matching algorithm inspired by fzf: https://github.com/junegunn/fzf
/// Searches for subsequences where characters must appear in order but not necessarily consecutively
struct FuzzyMatcher {

    // MARK: - Scoring Constants

    /// Bonus for consecutive character matches
    private static let consecutiveBonus: Int = 16

    /// Bonus for matching at the start of a word
    private static let wordStartBonus: Int = 32

    /// Bonus for matching after a separator (space, dash, underscore)
    private static let separatorBonus: Int = 24

    /// Bonus for matching at the very beginning of the text
    private static let firstCharBonus: Int = 48

    /// Penalty per character gap between matches
    private static let gapPenalty: Int = 3

    /// Maximum penalty for gaps (capped to avoid excessive penalties for long texts)
    private static let maxGapPenalty: Int = 24

    /// Base score per matched character
    private static let matchScore: Int = 16

    // MARK: - Public API

    /// Calculates a fuzzy match score between a pattern and a text
    /// - Parameters:
    ///   - pattern: The search pattern (user input)
    ///   - text: The text to search in (prompt)
    /// - Returns: A score >= 0 if there's a match, or nil if no match
    static func score(pattern: String, in text: String) -> Int? {
        let patternLower = pattern.lowercased()
        let textLower = text.lowercased()

        guard !patternLower.isEmpty else { return nil }
        guard !textLower.isEmpty else { return nil }

        let patternChars = Array(patternLower)
        let textChars = Array(textLower)

        // Try to find all pattern characters in order
        var matchPositions: [Int] = []
        var textIndex = 0

        for patternChar in patternChars {
            var found = false
            while textIndex < textChars.count {
                if textChars[textIndex] == patternChar {
                    matchPositions.append(textIndex)
                    textIndex += 1
                    found = true
                    break
                }
                textIndex += 1
            }
            if !found {
                return nil // Pattern character not found
            }
        }

        // Calculate score based on match positions
        return calculateScore(matchPositions: matchPositions, textChars: textChars)
    }

    /// Returns matches sorted by score (highest first)
    /// - Parameters:
    ///   - pattern: The search pattern
    ///   - candidates: List of strings to search in
    /// - Returns: Array of (text, score) tuples, sorted by score descending
    static func match(pattern: String, in candidates: [String]) -> [(text: String, score: Int)] {
        var results: [(text: String, score: Int)] = []

        for candidate in candidates {
            if let matchScore = score(pattern: pattern, in: candidate) {
                results.append((candidate, matchScore))
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Private Helpers

    private static func calculateScore(matchPositions: [Int], textChars: [Character]) -> Int {
        guard !matchPositions.isEmpty else { return 0 }

        var totalScore = 0

        for (index, position) in matchPositions.enumerated() {
            // Base score for each match
            totalScore += matchScore

            // First character bonus
            if position == 0 {
                totalScore += firstCharBonus
            }

            // Consecutive bonus (current position is right after previous match)
            if index > 0 && position == matchPositions[index - 1] + 1 {
                totalScore += consecutiveBonus
            }

            // Word start bonus (character after separator or at start)
            if position > 0 {
                let prevChar = textChars[position - 1]
                if isSeparator(prevChar) {
                    totalScore += separatorBonus
                } else if isWordBoundary(prevChar: prevChar, currChar: textChars[position]) {
                    totalScore += wordStartBonus
                }
            }

            // Gap penalty
            if index > 0 {
                let gap = position - matchPositions[index - 1] - 1
                if gap > 0 {
                    let penalty = min(gap * gapPenalty, maxGapPenalty)
                    totalScore -= penalty
                }
            }
        }

        return max(0, totalScore)
    }

    private static func isSeparator(_ char: Character) -> Bool {
        return char == " " || char == "-" || char == "_" || char == "/" || char == "." || char == ","
    }

    private static func isWordBoundary(prevChar: Character, currChar: Character) -> Bool {
        // Transition from lowercase to uppercase (camelCase)
        let prevIsLower = prevChar.isLowercase
        let currIsUpper = currChar.isUppercase
        return prevIsLower && currIsUpper
    }
}

// MARK: - Convenience Extension

extension FuzzyMatcher {
    /// Scores entries and returns them sorted by combined score
    /// - Parameters:
    ///   - pattern: The search pattern
    ///   - entries: The prompt history entries to search
    ///   - currentAppName: The current app's name (for app match bonus)
    /// - Returns: Array of scored entries, sorted by score descending
    static func scoreEntries(
        pattern: String,
        entries: [QuickEditPromptHistoryEntry],
        currentAppName: String?
    ) -> [ScoredPromptHistoryEntry] {
        let config = QuickEditPromptHistoryConfig.self

        var results: [ScoredPromptHistoryEntry] = []

        for entry in entries {
            guard let fuzzyScore = score(pattern: pattern, in: entry.text) else {
                continue
            }

            // Normalize fuzzy score (rough normalization, max reasonable score ~200)
            let normalizedFuzzyScore = Double(fuzzyScore) / 200.0

            // Calculate frequency score (log scale to avoid dominant high-usage prompts)
            let frequencyScore = Darwin.log(Double(entry.usageCount) + 1) / Darwin.log(10.0) // log10(usageCount + 1)

            // Calculate recency score (1.0 for today, decaying to 0 over recencyDaysThreshold days)
            let daysSinceUse = Date().timeIntervalSince(entry.lastUsedAt) / (24 * 60 * 60)
            let recencyScore = max(0, 1.0 - (daysSinceUse / config.recencyDaysThreshold))

            // App match bonus
            let appBonus: Double
            if let currentApp = currentAppName,
               let entryApp = entry.appName,
               currentApp == entryApp {
                appBonus = config.appMatchBonus
            } else {
                appBonus = 0
            }

            // Calculate final score
            let finalScore = (normalizedFuzzyScore * config.fuzzyMatchWeight)
                + (frequencyScore * config.frequencyWeight)
                + (recencyScore * config.recencyWeight)
                + appBonus

            results.append(ScoredPromptHistoryEntry(entry: entry, score: finalScore))
        }

        // Sort by score descending
        return results.sorted { $0.score > $1.score }
    }
}
