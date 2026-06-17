//
//  CustomPromptFormContent.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import KeyboardShortcuts
import SwiftUI

/// Shared form content for creating or editing a custom prompt
/// Used by both CustomPromptFormView (Settings) and CustomPromptEditorWindowView (QuickEdit)
struct CustomPromptFormContent: View {
    // MARK: - Bindings

    @Binding var name: String
    @Binding var promptText: String
    @Binding var selectedIcon: String
    @Binding var selectedApps: [String]
    @Binding var showIconPicker: Bool

    // MARK: - Properties

    let promptId: UUID

    // MARK: - State
    
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var showAppSelector: Bool = false
    @State private var appSearchText: String = ""

    // MARK: - Computed Properties

    private var allApps: [URL] {
        FileManager.default.installedApps()
            .sorted {
                let left = $0.deletingPathExtension().lastPathComponent.lowercased()
                let right = $1.deletingPathExtension().lastPathComponent.lowercased()
                return left < right
            }
            .filter { url in
                guard let bundleId = Bundle(url: url)?.bundleIdentifier else { return false }
                return !selectedApps.contains(bundleId)
            }
    }

    private var filteredApps: [URL] {
        if appSearchText.isEmpty {
            return allApps
        } else {
            return allApps.filter { url in
                url.deletingPathExtension().lastPathComponent
                    .localizedCaseInsensitiveContains(appSearchText)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            iconAndNameField
            promptField
            shortcutField
            applicationsField
        }
    }

    // MARK: - Components

    private var iconAndNameField: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon section
            VStack(alignment: .leading, spacing: 8) {
                Text(String.localized("Icon", table: "Settings"))
                    .font(.headline)
                    .foregroundStyle(Color.S_1)

                Button(action: { showIconPicker = true }) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Color.T_9)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.genericBorder)
                        )
                }
                .buttonStyle(.plain)
            }

            // Name section
            VStack(alignment: .leading, spacing: 8) {
                Text(String.localized("Name", table: "Settings"))
                    .font(.headline)
                    .foregroundStyle(Color.S_1)
                TextField(String.localized("Improve", table: "Settings"), text: $name)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .frame(height: 44)
                    .background(Color.T_9)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.genericBorder)
                    )
            }
        }
    }

    private var promptField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String.localized("Prompt", table: "Settings"))
                .font(.headline)
                .foregroundStyle(Color.S_1)
            VStack {
                TextEditor(text: $promptText)
                    .textEditorStyle(.plain)
                    .frame(height: 100)
                    .foregroundStyle(Color.S_0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 3)
            .background(Color.T_9)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.genericBorder)
            )
        }
    }

    private var shortcutField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String.localized("Keyboard Shortcut (Optional)", table: "Settings"))
                .font(.headline)
                .foregroundStyle(Color.S_1)

            KeyboardShortcuts.Recorder("", name: KeyboardShortcuts.Name(promptId.uuidString))
                .padding(4)
        }
    }

    private var applicationsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String.localized("Applications (Optional)", table: "Settings"))
                .font(.headline)
                .foregroundStyle(Color.S_1)
            Text(String.localized("When specified, this prompt will only appear in these applications.", table: "Settings"))
                .font(.caption)
                .foregroundStyle(Color.S_2)

            // Selected apps
            if !selectedApps.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedApps, id: \.self) { bundleId in
                        selectedAppTag(bundleId: bundleId)
                    }
                }
            }

            // Add app button
            Button(action: { showAppSelector.toggle() }) {
                HStack {
                    Image(systemName: "plus")
                    Text(String.localized("Add Application", table: "Settings"))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.T_9)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.genericBorder)
            )
            .popover(isPresented: $showAppSelector) {
                appSelectorPopover
            }
        }
    }

    private func selectedAppTag(bundleId: String) -> some View {
        let appName = getAppName(for: bundleId)
        let appIcon = getAppIcon(for: bundleId)

        return HStack(spacing: 4) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(appName)
                .font(.caption)
            Button(action: {
                selectedApps.removeAll { $0 == bundleId }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.T_8)
        .cornerRadius(12)
    }

    private var appSelectorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localized("Select Application", table: "Settings"))
                .font(.headline)
                .foregroundStyle(Color.S_1)

            TextField(String.localized("Search applications...", table: "Settings"), text: $appSearchText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.S_7)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.S_5)
                )

            VStack {
                if filteredApps.isEmpty {
                    Text(String.localized("No applications found", table: "Settings"))
                        .foregroundStyle(Color.S_2)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredApps, id: \.self) { url in
                                Button(action: {
                                    if let bundleId = Bundle(url: url)?.bundleIdentifier {
                                        selectedApps.append(bundleId)
                                    }
                                    appSearchText = ""
                                    showAppSelector = false
                                }) {
                                    HStack {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .foregroundStyle(Color.S_0)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 300)
        }
        .padding(16)
        .frame(width: 300)
        .background(Color.S_8)
    }

    // MARK: - Helpers

    private func getAppName(for bundleId: String) -> String {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return appUrl.deletingPathExtension().lastPathComponent
        }
        return bundleId
    }

    private func getAppIcon(for bundleId: String) -> NSImage? {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        return nil
    }
}
