//
//  KeystrokeNotificationManager.swift
//  Onit
//
//  Created by Timothy Lenardo on 7/24/25.
//

import AppKit
import Defaults
import Foundation

struct KeystrokeEvent {
    let event: NSEvent
    let modifierStates: (command: Bool, control: Bool, shift: Bool, option: Bool)
}

// MARK: - Keystroke Notification Manager
@MainActor
final class KeystrokeNotificationManager: ObservableObject {

    // MARK: - Singleton instance

    static let shared = KeystrokeNotificationManager()

    // MARK: - Properties

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var mouseEventMonitor: Any?

    private var isHidRemappingApplied: Bool = false

    private var isMonitoring: Bool = false

    // MARK: - Delegates
    private var delegates = NSHashTable<AnyObject>.weakObjects()

    func addDelegate(_ delegate: KeystrokeNotificationDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: KeystrokeNotificationDelegate) {
        delegates.remove(delegate)
    }

    private func notifyDelegates(_ notification: (KeystrokeNotificationDelegate) -> Void) {
        for case let delegate as KeystrokeNotificationDelegate in delegates.allObjects {
            notification(delegate)
        }
    }

    // MARK: - Private initializer

    private init() {
        startMonitoring()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Monitor all events
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyboardEvent(event)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyboardEvent(event)
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else {
            return
        }

        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        if let mouseEventMonitor = mouseEventMonitor {
            NSEvent.removeMonitor(mouseEventMonitor)
            self.mouseEventMonitor = nil
        }

        isMonitoring = false
    }
    
    // MARK: - HID Remapping Management

    /// Apply all currently-needed HID remappings in one hidutil call.
    /// Calling this is always safe — it recalculates the full needed set, so it can
    /// also be used to *remove* a single mapping when another is still needed.
    /// - Parameter context: A string describing the context for logging purposes
    func applyHIDRemapping(context: String = "Manual") {
        guard !TestEnvironment.isRunningTests() else { return }
        applyNeededHIDMappings(context: context)
    }

    /// Restore the default HID mapping (remove all remappings by applying their reverses).
    func removeHIDRemapping() {
        guard !TestEnvironment.isRunningTests() else { return }
        restoreHIDMappingToDefault()
    }

    /// Check if the HID remapping is currently applied
    var isHIDRemappingApplied: Bool {
        return isHidRemappingApplied
    }

    /// Check if CapsLock HID remapping is needed by any feature.
    func isHIDRemappingNeededForCapsLock() -> Bool {
        return !Defaults[.capsLockModifierShortcuts].isEmpty
    }

    /// Check if any feature currently needs any HID remapping.
    func isHIDRemappingNeededByAnyFeature() -> Bool {
        return isHIDRemappingNeededForCapsLock()
    }

    /// Remove HID remapping if nothing needs it; otherwise re-apply only what is still needed.
    /// This correctly handles the case where one of two active remappings is no longer needed.
    func removeHIDRemappingIfNotNeeded() {
        if !isHIDRemappingNeededByAnyFeature() {
            removeHIDRemapping()
        } else {
            // Re-apply only the mappings still needed; this also removes any that are no longer needed.
            applyHIDRemapping(context: "PartialRemove-Reapply")
        }
    }

    // MARK: - Private Methods

    private func handleKeyboardEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            handleKeyDown(event: event)
        } else if event.type == .flagsChanged {
            handleFlagsChanged(event: event)
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        // Notify delegates about modifier key changes (Shift, Cmd, etc.)
        let flags = event.modifierFlags
        let modifierStates = (
            command: flags.contains(.command),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            option: flags.contains(.option)
        )
        let keystrokeEvent = KeystrokeEvent(event: event, modifierStates: modifierStates)

        notifyDelegates { delegate in
            delegate.keystrokeNotificationManager(self, didReceiveKeystroke: keystrokeEvent)
        }
    }

    private func handleKeyDown(event: NSEvent) {
        let flags = event.modifierFlags
        let modifierStates = (
            command: flags.contains(.command),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            option: flags.contains(.option)
        )
        let keystrokeEvent = KeystrokeEvent(event: event, modifierStates: modifierStates)

        // Notify all callbacks
        notifyDelegates { delegate in
            delegate.keystrokeNotificationManager(self, didReceiveKeystroke: keystrokeEvent)
        }
    }

    // MARK: - Utility Methods

    func getCurrentModifierStates() -> (command: Bool, control: Bool, shift: Bool, option: Bool) {
        let flags = NSEvent.modifierFlags
        
        return (
            command: flags.contains(.command),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            option: flags.contains(.option)
        )
    }
    
    /// Restore all possible HID remappings to their defaults.
    /// Applies the inverse mapping (F18→CapsLock) in a single hidutil call.
    private func restoreHIDMappingToDefault() {
        let process = Process()
        let revertMapping = """
            [
                {
                    \"HIDKeyboardModifierMappingSrc\":\(HIDUsageIDs.f18.hidUsageCode),
                    \"HIDKeyboardModifierMappingDst\":\(HIDUsageIDs.capsLock.hidUsageCode)
                }
            ]
        """

        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", "{\"UserKeyMapping\":\(revertMapping)}"]

        do {
            let semaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in
                semaphore.signal()
            }
            try process.run()
            // Wait up to 5 seconds to avoid blocking app termination indefinitely
            let result = semaphore.wait(timeout: .now() + 5)

            if result == .timedOut {
                log.error("Timed out waiting for hidutil to restore keyboard mappings")
                process.terminate()
            } else if process.terminationStatus != 0 {
                log.error("Failed to restore keyboard mappings (status \(process.terminationStatus))")
            }
        } catch {
            log.error("Exception while restoring keyboard mappings: \(error.localizedDescription)")
        }
    }

    /// Build and apply the full set of currently-needed HID mappings in a single hidutil call.
    /// hidutil --set replaces ALL previous mappings, so we must always send the complete desired set.
    private func applyNeededHIDMappings(context: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        // The key mappings are documented here:
        // https://developer.apple.com/library/archive/technotes/tn2450/_index.html

        var entries: [String] = []

        if isHIDRemappingNeededForCapsLock() {
            entries.append("""
                {
                    "HIDKeyboardModifierMappingSrc": \(HIDUsageIDs.capsLock.hidUsageCode),
                    "HIDKeyboardModifierMappingDst": \(HIDUsageIDs.f18.hidUsageCode)
                }
            """)
        }

        let mappingArray = "[\(entries.joined(separator: ","))]"
        let jsonPayload = "{\"UserKeyMapping\":\(mappingArray)}"

        log.info("HID Remapping: applying mappings (context: \(context)) capsLock=\(isHIDRemappingNeededForCapsLock())")

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", jsonPayload]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        Task(priority: .utility) { [weak self] in
            var commandOutput = ""
            var processResult: Result<Bool, Error> = .failure(NSError(domain: "Unknown", code: -1))
            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let outStr = String(data: outputData, encoding: .utf8), !outStr.isEmpty { commandOutput += "Output:\n\(outStr)\n" }
                if let errStr = String(data: errorData, encoding: .utf8), !errStr.isEmpty { commandOutput += "Error Output:\n\(errStr)" }
                commandOutput = commandOutput.trimmingCharacters(in: .whitespacesAndNewlines)

                if process.terminationStatus == 0 {
                    processResult = .success(true)
                } else {
                    log.warning("Hidutil: FAILED (status \(process.terminationStatus)) (\(context)) - Could not enable remapping.")
                    if !commandOutput.isEmpty {
                        log.error("Hidutil details: \(commandOutput)")
                    }
                    processResult = .success(false)
                    // Don't change isHidRemappingApplied on failure — system state is now uncertain.
                }
            } catch {
                log.error("Hidutil process EXCEPTION (\(context)): \(error.localizedDescription)")
                processResult = .failure(error)
                // Don't change isHidRemappingApplied on exception.
            }

            await MainActor.run {
                switch processResult {
                case .success(let success):
                    if success {
                        self?.isHidRemappingApplied = true
                    }
                case .failure:
                    break
                }
            }
        }
    }
}
