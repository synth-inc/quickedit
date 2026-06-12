//
//  CustomPromptRow.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Non-Dragging Window View

/// An NSView that prevents window dragging when clicking on it
private class NonDraggingNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

/// A SwiftUI wrapper for NonDraggingNSView
private struct NonDraggingWindowView: NSViewRepresentable {
    func makeNSView(context: NSViewRepresentableContext<NonDraggingWindowView>) -> NonDraggingNSView {
        let view = NonDraggingNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NonDraggingNSView, context: NSViewRepresentableContext<NonDraggingWindowView>) {}
}

/// A row representing a custom prompt in the settings list
struct CustomPromptRow: View {
    // MARK: - Properties

    let prompt: CustomPrompt
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: (Bool) -> Void
    let onDragStarted: () -> Void
    let onDrop: (CustomPrompt) -> Void

    // MARK: - State

    @State private var isHovered: Bool = false
    @State private var isDragHandleHovered: Bool = false
    @State private var isTargeted: Bool = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle with non-dragging window overlay
            ZStack {
                NonDraggingWindowView()

                Image(systemName: "line.3.horizontal")
                    .foregroundColor(isDragHandleHovered ? Color.S_1 : Color.S_3)
                    .font(.system(size: 12))
            }
            .frame(width: 16, height: 24)
            .contentShape(Rectangle())
            .onHover { hovering in
                isDragHandleHovered = hovering
                if hovering {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .draggable(prompt.id.uuidString) {
                // Drag preview
                HStack(spacing: 8) {
                    Image(systemName: prompt.icon)
                        .font(.system(size: 14))
                    Text(prompt.name)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.S_6)
                .cornerRadius(6)
                .onAppear {
                    onDragStarted()
                }
            }

            // Checkbox
            Toggle("", isOn: Binding(
                get: { prompt.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            // Shared prompt row view (icon + name + shortcut/actions)
            PromptRowView(
                prompt: prompt,
                isHovered: isHovered,
                showButtonTitles: true,
                onEdit: onEdit,
                onDelete: onDelete
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Group {
                if isTargeted {
                    Color.accentColor.opacity(0.15)
                } else if isHovered {
                    Color.S_0.opacity(0.05)
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .dropDestination(for: String.self) { items, _ in
            guard let droppedId = items.first,
                  let uuid = UUID(uuidString: droppedId),
                  uuid != prompt.id else {
                return false
            }
            // Find the dropped prompt and trigger reorder
            if let droppedPrompt = CustomPromptManager.shared.customPrompts.first(where: { $0.id == uuid }) {
                onDrop(droppedPrompt)
            }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
