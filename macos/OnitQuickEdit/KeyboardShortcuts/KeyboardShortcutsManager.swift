//
//  KeyboardShortcutsManager.swift
//  Onit
//
//  Created by Kévin Naudin on 11/02/2025.
//

@preconcurrency import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import PostHog

@MainActor
class KeyboardShortcutsManager {

    private static var didObserveAppActiveNotifications = false

    private static var quickEditShortcutsEnabled = false
    private static var quickEditGlobalShortcutsEnabled = false
    private static var customPromptShortcutsEnabled = false

    // Custom prompt shortcuts (dynamically registered)
    private static var customPromptShortcuts: [KeyboardShortcuts.Name] = []

    // Custom prompt shortcut data (stored separately from the library to avoid auto-registration)
    private static var customPromptShortcutData: [String: (shortcut: KeyboardShortcuts.Shortcut, promptId: UUID)] = [:]
    private static var customPromptHandlersRegistered = Set<String>()

    // Dev build coexistence state
    private static var devBuildCancellables = Set<AnyCancellable>()
    private static var isDisabledForDevBuild = false

    private init() {}

    // QuickEdit shortcuts (enabled only when content is ready to insert)
    private static let quickEditShortcuts: [KeyboardShortcuts.Name] = [
        .quickEditInsert
    ]

    // QuickEdit global shortcuts (enabled when hint is visible)
    private static let quickEditGlobalShortcuts: [KeyboardShortcuts.Name] = [
        .quickEditImprove,
        .quickEditPrompt
    ]

    static var capsLockModifierShortcuts: [KeyboardShortcuts.Name] {
        get {
            return Defaults[.capsLockModifierShortcuts].compactMap { nameString in
                KeyboardShortcuts.Name.allCases.first { $0.rawValue == nameString }
            }
        }
        set {
            Defaults[.capsLockModifierShortcuts] = newValue.map { $0.rawValue }
        }
    }
    
    static func configure() {
        registerRemappedKeyHandlers()
        registerQuickEditShortcuts()
        registerQuickEditGlobalShortcuts()
        registerCustomPromptShortcuts()

        // Disable quickEdit shortcuts (only enabled when quickEdit UI is ready for insert)
        KeyboardShortcuts.disable(quickEditShortcuts)
        quickEditShortcutsEnabled = false

        // Disable quickEdit global shortcuts (only enabled when hint is visible)
        KeyboardShortcuts.disable(quickEditGlobalShortcuts)
        quickEditGlobalShortcutsEnabled = false

        // Disable custom prompt shortcuts (only enabled when hint is visible)
        KeyboardShortcuts.disable(customPromptShortcuts)
        customPromptShortcutsEnabled = false

        KeyboardShortcuts.enable([.remappedKeyConsumer, .remappedKeyConsumerShifted])

        KeyboardShortcuts.disable(capsLockModifierShortcuts)

        // Apply or remove HID remappings based on what features currently need.
        // This also cleans up stale mappings from a previous crash/force-quit.
        if KeystrokeNotificationManager.shared.isHIDRemappingNeededByAnyFeature() {
            KeystrokeNotificationManager.shared.applyHIDRemapping(context: "Startup")
        } else {
            KeystrokeNotificationManager.shared.removeHIDRemapping()
        }
    }
    
    static func setShortcut(name: KeyboardShortcuts.Name, shortcut: KeyboardShortcuts.Shortcut, usesCapsLockModifier: Bool) {
        var currentShortcuts = Self.capsLockModifierShortcuts
        
        if (usesCapsLockModifier) {
            // Add the shortcut to the list of capsLockShortcuts if not already present
            if !currentShortcuts.contains(name) {
                currentShortcuts.append(name)
            }
        } else {
            // Remove the shortcut from the list of capsLockShortcuts if present
            currentShortcuts.removeAll { $0 == name }
        }
        
        // Update the persistent storage
        Self.capsLockModifierShortcuts = currentShortcuts
        KeyboardShortcuts.setShortcut(shortcut, for: name)

        // Re-evaluate HID remapping: apply if CapsLock is now needed, remove if not
        if KeystrokeNotificationManager.shared.isHIDRemappingNeededByAnyFeature() {
            KeystrokeNotificationManager.shared.applyHIDRemapping(context: "CapsLockModifierShortcut")
        } else {
            KeystrokeNotificationManager.shared.removeHIDRemappingIfNotNeeded()
        }
    }

    static func enableQuickEditShortcutsIfNeeded() {
        // Only enable if QuickEdit feature is enabled
        guard Defaults[.quickEditConfig].isEnabled else { return }
        if !quickEditShortcutsEnabled {
            quickEditShortcutsEnabled = true
            KeyboardShortcuts.enable(quickEditShortcuts)
        }
    }

    static func disableQuickEditShortcutsIfNeeded() {
        if quickEditShortcutsEnabled {
            quickEditShortcutsEnabled = false
            KeyboardShortcuts.disable(quickEditShortcuts)
        }
    }

    static func enableQuickEditGlobalShortcutsIfNeeded() {
        // Only enable if QuickEdit feature is enabled
        guard Defaults[.quickEditConfig].isEnabled else { return }
        if !quickEditGlobalShortcutsEnabled {
            quickEditGlobalShortcutsEnabled = true
            KeyboardShortcuts.enable(quickEditGlobalShortcuts)
        }
        enableCustomPromptShortcutsIfNeeded()
    }

    static func disableQuickEditGlobalShortcutsIfNeeded() {
        if quickEditGlobalShortcutsEnabled {
            quickEditGlobalShortcutsEnabled = false
            KeyboardShortcuts.disable(quickEditGlobalShortcuts)
        }
        disableCustomPromptShortcutsIfNeeded()
    }

    static func enableCustomPromptShortcutsIfNeeded() {
        // Only enable if QuickEdit feature is enabled (custom prompts are part of QuickEdit)
        guard Defaults[.quickEditConfig].isEnabled else { return }
        if !customPromptShortcutsEnabled && !customPromptShortcuts.isEmpty {
            customPromptShortcutsEnabled = true
            registerCustomPromptHandlersIfNeeded()
            KeyboardShortcuts.enable(customPromptShortcuts)
        }
    }

    static func disableCustomPromptShortcutsIfNeeded() {
        if customPromptShortcutsEnabled {
            customPromptShortcutsEnabled = false
            KeyboardShortcuts.disable(customPromptShortcuts)
        }
    }

    static func resetKeyboardShortcut(
        for shortcutName: KeyboardShortcuts.Name,
        to previousShortcut: KeyboardShortcuts.Shortcut? = nil
    ) {
        if let previousShortcut = previousShortcut {
            KeyboardShortcuts.setShortcut(previousShortcut, for: shortcutName)
        } else {
            KeyboardShortcuts.reset(shortcutName)
        }
    }
    
    // MARK: - Caps Lock State

    private static var isCapsLockPressed: Bool = false

    private static func onCapsDown() {
        guard !isCapsLockPressed else { return }
        isCapsLockPressed = true

        executeCapsLockTappedShortcutsIfNeeded()
    }

    private static func onCapsUp() {
        guard isCapsLockPressed else { return }
        isCapsLockPressed = false
    }

    private static func registerRemappedKeyHandlers() {
        KeyboardShortcuts.onKeyDown(for: .remappedKeyConsumer) {
            Task { @MainActor in
                Self.onCapsDown()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .remappedKeyConsumer) {
            Task { @MainActor in
                Self.onCapsUp()
            }
        }
        KeyboardShortcuts.onKeyDown(for: .remappedKeyConsumerShifted) {
            Task { @MainActor in
                CapsLockToggleManager.toggle()
            }
        }
    }

    private static func registerQuickEditShortcuts() {
        quickEditShortcuts.forEach { name in
            KeyboardShortcuts.onKeyUp(for: name) {
                Task { @MainActor in
                    executeShortcut(name: name)
                }
            }
        }
    }

    private static func registerQuickEditGlobalShortcuts() {
        quickEditGlobalShortcuts.forEach { name in
            KeyboardShortcuts.onKeyUp(for: name) {
                Task { @MainActor in
                    executeShortcut(name: name)
                }
            }
        }
    }
    
    /// Registers keyboard shortcuts for all custom prompts with shortcuts
    private static func registerCustomPromptShortcuts() {
        Task { @MainActor in
            await refreshCustomPromptShortcuts()
        }
    }

    /// Refreshes custom prompt shortcuts (call when prompts are added/updated/deleted)
    static func refreshCustomPromptShortcuts() async {
        // Disable and clear existing shortcuts
        if !customPromptShortcuts.isEmpty {
            KeyboardShortcuts.disable(customPromptShortcuts)
            customPromptShortcuts.removeAll()
        }
        customPromptShortcutData.removeAll()

        // Get all prompts with shortcuts
        let prompts = await CustomPromptManager.shared.fetchAllPrompts()

        for prompt in prompts {
            guard let shortcutData = prompt.shortcutData,
                  let shortcut = CustomPromptManager.shared.decodeShortcut(shortcutData)
            else { continue }

            let name = KeyboardShortcuts.Name(prompt.id.uuidString)
            customPromptShortcuts.append(name)
            customPromptShortcutData[name.rawValue] = (shortcut: shortcut, promptId: prompt.id)
        }

        // Only register with the library when shortcuts should be active
        if customPromptShortcutsEnabled && !customPromptShortcuts.isEmpty {
            registerCustomPromptHandlersIfNeeded()
            KeyboardShortcuts.enable(customPromptShortcuts)
        }
    }

    /// Registers shortcuts and onKeyUp handlers for custom prompt shortcuts.
    /// Called only when shortcuts should be active (enable path).
    /// setShortcut() is called here (not in refresh) to avoid registering Carbon hotkeys at startup.
    private static func registerCustomPromptHandlersIfNeeded() {
        for (nameRaw, data) in customPromptShortcutData {
            let name = KeyboardShortcuts.Name(nameRaw)

            // Register the shortcut with the library (stores in UserDefaults + registers Carbon hotkey)
            KeyboardShortcuts.setShortcut(data.shortcut, for: name)

            // Register the handler only once per name to avoid duplicate dispatch
            if !customPromptHandlersRegistered.contains(nameRaw) {
                KeyboardShortcuts.onKeyUp(for: name) {
                    Task { @MainActor in
                        executeCustomPromptShortcut(promptId: data.promptId)
                    }
                }
                customPromptHandlersRegistered.insert(nameRaw)
            }
        }
    }

    /// Executes a custom prompt shortcut
    private static func executeCustomPromptShortcut(promptId: UUID) {
        Task { @MainActor in
            guard let prompt = CustomPromptManager.shared.customPrompts.first(where: { $0.id == promptId }),
                  prompt.isEnabled
            else { return }

            AnalyticsManager.shortcutPressed(for: "customPrompt_\(prompt.name)", panelOpened: false)
            QuickEditManager.shared.executeCustomPrompt(prompt)
        }
    }
    
    // MARK: - Execution
    
    private static func executeShortcut(name: KeyboardShortcuts.Name) {
        AnalyticsManager.shortcutPressed(for: name.rawValue, panelOpened: false)

        switch name {
        case .quickEditImprove:
            QuickEditManager.shared.improve()
        case .quickEditPrompt:
            QuickEditManager.shared.prompt()
        case .quickEditInsert:
            Task { await QuickEditManager.shared.insertResponse() }

        default:
            print("KeyboardShortcut not handled: \(name)")
        }
    }
    
    static func executeCapsLockTappedShortcutsIfNeeded() {
        let eventMods = KeystrokeNotificationManager.shared.getCurrentModifierStates()

        for name in KeyboardShortcuts.Name.allCases {
            if let shortcut = KeyboardShortcuts.getShortcut(for: name),
               shortcut.key == .capsLock {
                let shortcutMods = shortcut.modifiers
                let matches = [
                    (eventMods.command, shortcutMods.contains(.command)),
                    (eventMods.control, shortcutMods.contains(.control)),
                    (eventMods.shift, shortcutMods.contains(.shift)),
                    (eventMods.option, shortcutMods.contains(.option))
                ].allSatisfy { $0.0 == $0.1 }
                if !matches { continue }
                executeShortcut(name: name)
            }
        }
    }

    // MARK: - Dev Build Coexistence

    /// Start observing dev build detection service (Release builds only)
    static func observeDevBuildDetection() {
        #if !DEBUG
        DevBuildDetectionService.shared.$isDevBuildRunning
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { isDevBuildRunning in
                if isDevBuildRunning {
                    disableAllForDevBuildCoexistence()
                } else {
                    restoreAfterDevBuildCoexistence()
                }
            }
            .store(in: &devBuildCancellables)
        #endif
    }

    /// Disable all shortcuts when dev build is running
    private static func disableAllForDevBuildCoexistence() {
        guard !isDisabledForDevBuild else { return }
        isDisabledForDevBuild = true

        // Disable all registered shortcuts
        var allShortcuts: [KeyboardShortcuts.Name] = []
        allShortcuts.append(contentsOf: quickEditShortcuts)
        allShortcuts.append(contentsOf: quickEditGlobalShortcuts)
        allShortcuts.append(contentsOf: customPromptShortcuts)
        allShortcuts.append(.remappedKeyConsumer)
        allShortcuts.append(.remappedKeyConsumerShifted)
        KeyboardShortcuts.disable(allShortcuts)
    }

    /// Restore shortcuts when dev build is no longer running
    private static func restoreAfterDevBuildCoexistence() {
        guard isDisabledForDevBuild else { return }
        isDisabledForDevBuild = false

        // Re-enable shortcuts based on their previous state
        // remapped key consumers are always enabled
        KeyboardShortcuts.enable([.remappedKeyConsumer, .remappedKeyConsumerShifted])

        // Re-enable based on current state flags
        if quickEditShortcutsEnabled {
            KeyboardShortcuts.enable(quickEditShortcuts)
        }

        if quickEditGlobalShortcutsEnabled {
            KeyboardShortcuts.enable(quickEditGlobalShortcuts)
        }

        if customPromptShortcutsEnabled && !customPromptShortcuts.isEmpty {
            registerCustomPromptHandlersIfNeeded()
            KeyboardShortcuts.enable(customPromptShortcuts)
        }
    }
}
