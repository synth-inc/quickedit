//
//  PromptRowView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import SwiftUI

/// A shared view for displaying a custom prompt row with icon, name, and shortcut/actions
/// Used in both QuickEdit hint popover and Settings
struct PromptRowView: View {
    // MARK: - Observed Objects

    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Properties

    let prompt: CustomPrompt
    let isHovered: Bool
    let showButtonTitles: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: prompt.icon)
                .font(.system(size: 12))
                .frame(width: 18)
                .foregroundColor(Color.S_0.opacity(0.8))

            // Name
            Text(prompt.localizedName)
                .styleText(size: 13, weight: .medium, color: Color.S_0.opacity(0.8))
                .lineLimit(1)

            Spacer()

            if isHovered && !prompt.isSystemManaged {
                HStack(spacing: showButtonTitles ? 2 : 0) {
                    // Edit button
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(.edit)
                                .resizable()
                                .frame(width: 14, height: 14)
                            if showButtonTitles {
                                Text(String.localized("Edit", table: "QuickEdit"))
                                    .styleText(size: 11, weight: .regular)
                            }
                        }
                        .foregroundColor(Color.S_0.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, showButtonTitles ? 6 : 2)
                    .padding(.vertical, 2)

                    // Delete button
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(.circleX)
                                .resizable()
                                .frame(width: 14, height: 14)
                            if showButtonTitles {
                                Text(String.localized("Delete", table: "QuickEdit"))
                                    .styleText(size: 11, weight: .regular)
                            }
                        }
                        .foregroundColor(Color.S_0.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, showButtonTitles ? 6 : 2)
                    .padding(.vertical, 2)
                }
            } else {
                // Shortcut (if available)
                if let shortcutText = prompt.shortcutText {
                    Text(shortcutText)
                        .styleText(size: 11, color: Color.S_0.opacity(0.5))
                }
            }
        }
        .id(localization.currentLanguage)
    }
}
