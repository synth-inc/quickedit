//
//  AppWindowManager.swift
//  Onit
//
//  Created by Loyd Kim on 4/28/26.
//

import AppKit
import Defaults

@MainActor
final class AppWindowManager: NSObject, NSWindowDelegate, ObservableObject {
    // MARK: - Singleton

    static let shared = AppWindowManager()

    // MARK: - Private Variables

    private var window: AppWindow? = nil

    // MARK: - Public Functions

    func showWindow(settingsPage: SettingsPage? = nil) {
        if let settingsPage {
            Defaults[.settingsPage] = settingsPage
        }

        // Only count this as an "open" when the window is actually transitioning
        // from absent/hidden to visible — refocus calls on an already-open window
        // shouldn't inflate the count.
        let isAlreadyVisible = window?.isVisible == true
        if !isAlreadyVisible {
            AnalyticsManager.AppNavigation.appWindowOpened()
        }

        if let existingWindow = window {
            showExistingWindow(existingWindow)
        } else {
            createWindow()
        }
    }

    func closeWindow() {
        if let window {
            window.close()
        }
    }

    // MARK: - Private Functions

    private func showExistingWindow(_ window: AppWindow) {
        if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func createWindow() {
        window = AppWindow()

        guard let window else { return }

        window.delegate = self
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate Protocol Conformance

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? AppWindow,
           window === self.window
        else {
            return
        }

        window.cleanupObservers()
        window.delegate = nil
        self.window = nil
    }
}
