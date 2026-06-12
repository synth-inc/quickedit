//
//  QuickEditHintPromptListView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import SwiftUI

/// Popover view showing the list of available custom prompts
struct QuickEditHintPromptListView: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @StateObject private var promptManager = CustomPromptManager.shared
    @State private var hoveredPromptId: UUID?

    // MARK: - Properties

    let currentAppBundleID: String?
    let onPromptSelected: (CustomPrompt) -> Void
    let onEditPrompt: (CustomPrompt) -> Void
    let onDeletePrompt: (CustomPrompt) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(availablePrompts) { prompt in
                PromptRowView(
                    prompt: prompt,
                    isHovered: hoveredPromptId == prompt.id,
                    showButtonTitles: false,
                    onEdit: {
                        onEditPrompt(prompt)
                    },
                    onDelete: {
                        onDeletePrompt(prompt)
                    }
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(height: 24)
                .frame(minWidth: 160)
                .background(hoveredPromptId == prompt.id ? Color.S_0.opacity(0.15) : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredPromptId = hovering ? prompt.id : nil
                }
                .onTapGesture {
                    onPromptSelected(prompt)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(Backgrounds.BrushedGlass())
        .cornerRadius(8)
        .addBorder(cornerRadius: 8, stroke: Color.T_7)
    }

    // MARK: - Computed Properties

    private var availablePrompts: [CustomPrompt] {
        promptManager.getEnabledPrompts(forApp: currentAppBundleID)
    }
}
