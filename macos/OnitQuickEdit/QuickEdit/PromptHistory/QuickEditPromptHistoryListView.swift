//
//  QuickEditPromptHistoryListView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/05/2025.
//

import SwiftUI
import AppKit

struct QuickEditPromptHistoryListView: View {

    // MARK: - Properties

    let suggestions: [ScoredPromptHistoryEntry]
    let selectedIndex: Int
    let onSelect: (ScoredPromptHistoryEntry) -> Void
    let onDelete: (ScoredPromptHistoryEntry) -> Void
    let onHover: (Int) -> Void

    // MARK: - Computed Properties

    private var isLightMode: Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }

    /// Returns suggestions in display order
    /// Always reversed so first item (index 0, most relevant) is at the bottom, closest to TextField
    private var displaySuggestions: [ScoredPromptHistoryEntry] {
        return suggestions.reversed()
    }

    /// Maps display index to actual suggestion index
    private func actualIndex(for displayIndex: Int) -> Int {
        return suggestions.count - 1 - displayIndex
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(displaySuggestions.enumerated()), id: \.element.id) { displayIdx, entry in
                        let actualIdx = actualIndex(for: displayIdx)

                        QuickEditPromptHistoryRowView(
                            entry: entry,
                            index: actualIdx,
                            isSelected: actualIdx == selectedIndex,
                            isLightMode: isLightMode,
                            onSelect: { onSelect(entry) },
                            onDelete: { onDelete(entry) },
                            onHover: onHover
                        )
                        .id("suggestion-\(actualIdx)")
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: QuickEditPromptHistoryConfig.maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                proxy.scrollTo("suggestion-\(newIndex)", anchor: .center)
            }
        }
    }
}
