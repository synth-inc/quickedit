//
//  SFSymbolPickerView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import AppKit
import SwiftUI

/// A SF Symbol picker with search functionality
struct SFSymbolPickerView: View {
    // MARK: - Bindings

    @Binding var selectedIcon: String

    // MARK: - State

    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    // MARK: - Computed Properties

    /// Filtered symbols based on search text
    private var filteredSymbols: [String] {
        if searchText.isEmpty {
            // Show a curated subset when not searching
            return suggestedSymbols
        }

        let searchLower = searchText.lowercased()

        // Filter from the complete list
        let matches = SFSymbolNames.allSymbols.filter { symbol in
            symbol.lowercased().contains(searchLower)
        }

        // If exact match exists, put it first
        if matches.contains(searchText.lowercased()) {
            var sorted = matches.sorted()
            if let index = sorted.firstIndex(of: searchText.lowercased()) {
                sorted.remove(at: index)
                sorted.insert(searchText.lowercased(), at: 0)
            }
            return Array(sorted.prefix(100)) // Limit results for performance
        }

        return Array(matches.sorted().prefix(100))
    }

    /// Quick access symbols shown when not searching
    private var suggestedSymbols: [String] {
        [
            "wand.and.sparkles.inverse", "wand.and.sparkles", "sparkles", "sparkle",
            "brain", "lightbulb", "lightbulb.fill",
            "pencil", "pencil.circle", "square.and.pencil", "highlighter",
            "doc.text", "text.alignleft", "text.quote",
            "message", "bubble.left", "quote.bubble", "paperplane", "envelope",
            "globe", "character.bubble", "abc",
            "checkmark", "checkmark.circle", "checkmark.circle.fill",
            "star", "star.fill", "heart", "heart.fill", "bolt", "bolt.fill",
            "gearshape", "wrench", "hammer", "scissors",
            "folder", "tag", "bookmark",
            "flame", "leaf", "crown", "flag", "bell", "clock", "person",
            "hand.thumbsup", "hand.wave", "hand.raised"
        ]
    }

    /// Check if search text is a valid SF Symbol (for the Use button)
    private var isSearchTextValidSymbol: Bool {
        guard !searchText.isEmpty else { return false }
        return NSImage(systemSymbolName: searchText, accessibilityDescription: nil) != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String.localized("Choose Icon", table: "Settings"))
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Search field
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(String.localized("Search icons...", table: "Settings"), text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if isSearchTextValidSymbol {
                                selectedIcon = searchText
                                dismiss()
                            } else if let first = filteredSymbols.first {
                                selectedIcon = first
                                dismiss()
                            }
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                if isSearchTextValidSymbol {
                    Button(String.localized("Use", table: "Settings")) {
                        selectedIcon = searchText
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Results header
            HStack {
                Text(searchText.isEmpty ? String.localized("Suggestions", table: "Settings") : String(format: String.localized("%d results", table: "Settings"), filteredSymbols.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Symbols grid
            ScrollView {
                if filteredSymbols.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text(String.localized("No symbols found", table: "Settings"))
                            .foregroundColor(.secondary)
                        if isSearchTextValidSymbol {
                            Text(String(format: String.localized("But \"%@\" is valid!", table: "Settings"), searchText))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            SymbolButton(
                                symbol: symbol,
                                isSelected: selectedIcon == symbol,
                                onTap: {
                                    selectedIcon = symbol
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 380, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            searchText = ""
        }
    }
}

// MARK: - Symbol Button

private struct SymbolButton: View {
    let symbol: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? Color.accentColor.opacity(0.2) :
                        (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
