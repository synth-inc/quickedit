//
//  QuickEditPromptBuilder.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import Foundation

/// Builds prompts for QuickEdit AI operations
enum QuickEditPromptBuilder {

    // MARK: - Post-processing

    /// Preserves leading/trailing whitespace and punctuation from original text
    static func preserveWhitespaceAndPunctuation(original: String, generated: String) -> String {
        var result = generated.trimmingCharacters(in: .whitespacesAndNewlines)

        // Preserve leading whitespace
        let leadingWhitespace = original.prefix(while: { $0.isWhitespace })
        if !leadingWhitespace.isEmpty {
            result = String(leadingWhitespace) + result
        }

        // Preserve trailing whitespace
        let trailingWhitespace = original.reversed().prefix(while: { $0.isWhitespace })
        if !trailingWhitespace.isEmpty {
            result = result + String(trailingWhitespace.reversed())
        }

        // Preserve trailing punctuation if original had it and generated doesn't
        let punctuationCharacters = CharacterSet(charactersIn: ".!?,;:")
        let originalTrimmed = original.trimmingCharacters(in: .whitespaces)
        let resultTrimmed = result.trimmingCharacters(in: .whitespaces)

        if let originalLastChar = originalTrimmed.last,
           originalLastChar.unicodeScalars.allSatisfy({ punctuationCharacters.contains($0) }) {
            if let resultLastChar = resultTrimmed.last,
               !resultLastChar.unicodeScalars.allSatisfy({ punctuationCharacters.contains($0) }) {
                // Insert punctuation before trailing whitespace
                let trailingWS = result.reversed().prefix(while: { $0.isWhitespace })
                let withoutTrailingWS = result.dropLast(trailingWS.count)
                result = withoutTrailingWS + String(originalLastChar) + String(trailingWS.reversed())
            }
        }

        return result
    }

    // MARK: - Selection-based Prompts

    /// Build instruction for retrying/regenerating selected text with context
    static func buildRetryInstruction(
        textBefore: String,
        selectedText: String,
        textAfter: String
    ) -> String {
        """
        Regenerate ONLY the portion of text marked between [START] and [END], providing an alternative version.

        Full text with markers:
        \"\"\"\(textBefore)[START]\(selectedText)[END]\(textAfter)\"\"\"

        Rules:
        - Output ONLY the replacement text (without [START]/[END] markers)
        - Maintain natural grammatical flow with the surrounding text
        - Do NOT add words before or after the marked portion
        - Preserve the original casing style (lowercase if preceded by a lowercase word, etc.)
        - Keep the same general meaning and tone
        """
    }

    /// Build instruction for AI-editing selected text with custom instruction and context
    static func buildAIEditInstruction(
        textBefore: String,
        selectedText: String,
        textAfter: String,
        userInstruction: String
    ) -> String {
        """
        Modify ONLY the portion of text marked between [START] and [END] according to the user's instruction.

        Full text with markers:
        \"\"\"\(textBefore)[START]\(selectedText)[END]\(textAfter)\"\"\"

        User instruction: \(userInstruction)

        Rules:
        - Output ONLY the replacement text (without [START]/[END] markers)
        - Maintain natural grammatical flow with the surrounding text
        - Do NOT add words before or after the marked portion
        - Preserve the original casing style unless the instruction requires otherwise
        """
    }

    // MARK: - Global Prompts

    /// Build instruction for global retry with frozen portions preserved
    static func buildGlobalRetryInstruction(
        originalInstruction: String,
        fullText: String,
        frozenPortions: [String]
    ) -> String {
        if frozenPortions.isEmpty {
            return """
            \(originalInstruction)

            Text to process:
            \"\"\"\(fullText)\"\"\"
            """
        }

        // Insert [FROZEN] markers around frozen portions in the text
        var markedText = fullText
        for portion in frozenPortions.reversed() {
            if let range = markedText.range(of: portion) {
                markedText.replaceSubrange(range, with: "[FROZEN]\(portion)[/FROZEN]")
            }
        }

        return """
        \(originalInstruction)

        Text to process (portions marked with [FROZEN]...[/FROZEN] must remain exactly as-is):
        \"\"\"\(markedText)\"\"\"

        Rules:
        - Text between [FROZEN] and [/FROZEN] must remain EXACTLY as-is in the same position
        - Rewrite ONLY the non-frozen portions according to the instruction
        - Output the complete text WITHOUT the [FROZEN] markers
        - Maintain natural flow between frozen and non-frozen portions
        """
    }
}
