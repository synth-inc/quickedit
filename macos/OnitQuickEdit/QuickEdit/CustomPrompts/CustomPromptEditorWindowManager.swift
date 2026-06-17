//
//  CustomPromptEditorWindowManager.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import AppKit

@MainActor
@Observable
final class CustomPromptEditorWindowManager: NSObject, NSWindowDelegate {
    // MARK: - Singleton

    static let shared = CustomPromptEditorWindowManager()

    // MARK: - Private Variables

    @ObservationIgnored
    private var window: CustomPromptEditorWindow?

    // MARK: - Private Functions

    private func showExistingWindow(_ window: CustomPromptEditorWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func createWindow(prompt: CustomPrompt?) {
        self.window = CustomPromptEditorWindow(prompt: prompt)

        guard let window = self.window else { return }

        window.delegate = self
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Public Functions

    func showWindow(prompt: CustomPrompt? = nil) {
        // Always create a new window with the correct prompt
        closeWindow()
        createWindow(prompt: prompt)
    }

    func closeWindow() {
        if let window = self.window {
            window.close()
        }
    }

    // MARK: - NSWindowDelegate Protocol Conformance

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? CustomPromptEditorWindow,
              window === self.window
        else {
            return
        }

        window.cleanupObservers()
        window.delegate = nil
        self.window = nil
    }
}
