//
//  QuickEditPromptHistoryRowView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import SwiftUI

struct QuickEditPromptHistoryRowView: View {

    // MARK: - Observed Objects

    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Properties

    let entry: ScoredPromptHistoryEntry
    let index: Int
    let isSelected: Bool
    let isLightMode: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onHover: ((Int) -> Void)?

    // MARK: - State

    @State private var isHovered: Bool = false
    @State private var isDeleteHovered: Bool = false

    // MARK: - Computed Properties

    private var textColor: Color {
        if isLightMode {
            Color.black.opacity(0.8)
        } else {
            Color.white.opacity(0.8)
        }
    }

    private var selectedTextColor: Color {
        if isLightMode {
            Color.black
        } else {
            Color.white
        }
    }

    private var selectedColor: Color {
        if isLightMode {
            Color.black.opacity(0.2)
        } else {
            Color.white.opacity(0.2)
        }
    }

    private var enterIconColor: Color {
        if isLightMode {
            Color.black.opacity(0.4)
        } else {
            Color.white.opacity(0.4)
        }
    }

    private var deleteButtonColor: Color {
        if isLightMode {
            Color.black.opacity(isDeleteHovered ? 0.8 : 0.3)
        } else {
            Color.white.opacity(isDeleteHovered ? 0.8 : 0.3)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return selectedColor
        } else {
            return Color.clear
        }
    }

    /// Truncates text to max lines with ellipsis
    private var displayText: String {
        let maxLines = QuickEditPromptHistoryConfig.maxPromptDisplayLines
        let lines = entry.text.components(separatedBy: .newlines)

        if lines.count <= maxLines {
            return entry.text
        }

        let truncatedLines = Array(lines.prefix(maxLines))
        return truncatedLines.joined(separator: "\n") + "..."
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            promptTextView

            Spacer(minLength: 0)

            enterIcon
                .opacity(isHovered || isSelected ? 1 : 0)
            deleteButton
                .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
            onHover?(hovering ? index : -1)
        }
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .id(localization.currentLanguage)
    }

    // MARK: - Subviews

    private var promptTextView: some View {
        Text(displayText)
            .styleText(weight: .regular, color: isSelected ? selectedTextColor : textColor)
            .lineLimit(QuickEditPromptHistoryConfig.maxPromptDisplayLines)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var enterIcon: some View {
        Image(.return)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 12, height: 12)
            .foregroundColor(enterIconColor)
            .frame(width: 20, height: 20)
    }

    private var deleteButton: some View {
        Button(action: {
            onDelete()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(deleteButtonColor)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle().size(width: 36, height: 36).offset(x: -8, y: -8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isDeleteHovered = hovering
        }
        .help(String.localized("Delete this prompt", table: "QuickEdit"))
    }
}
