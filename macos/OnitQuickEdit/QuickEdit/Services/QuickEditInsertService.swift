//
//  QuickEditInsertService.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import ApplicationServices
import AppKit

@MainActor
class QuickEditInsertService {

    // MARK: - Public Functions

    /// Inserts the generated text at the current cursor position
    /// - Parameters:
    ///   - text: The text to insert
    ///   - targetPid: If provided, posts the paste event directly to this process
    func insertText(_ text: String, targetPid: pid_t? = nil) async {
        guard !text.isEmpty else {
            return
        }

        // Use PasteboardManager for reliable insertion
        await PasteboardManager.shared.insertViaPaste(text, targetPid: targetPid)
    }

    /// Replaces the current selection with the generated text
    /// - Parameters:
    ///   - text: The text to insert (will replace current selection)
    ///   - targetPid: If provided, posts the paste event directly to this process
    func replaceSelection(with text: String, targetPid: pid_t? = nil) async {
        guard !text.isEmpty else {
            return
        }

        // When there's a selection, pasting will automatically replace it
        await PasteboardManager.shared.insertViaPaste(text, targetPid: targetPid)
    }

    /// Copies the text to clipboard without inserting
    /// - Parameter text: The text to copy
    func copyToClipboard(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
