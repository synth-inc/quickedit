//
//  HintActionButton.swift
//  Onit
//
//  Created by Kévin Naudin on 12/09/2025.
//

import SwiftUI

/// Shared action button component used in selection hints (SelectionHintView, UnfreezeHintView)
struct HintActionButton: View {
    let icon: ImageResource
    let text: String
    let action: () -> Void

    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color.S_0)
                .frame(width: 14, height: 14)

            Text(text)
                .styleText(size: 13, weight: .regular)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .addButtonEffects(
            hoverBackground: Color.S_0.opacity(0.2),
            cornerRadius: 6,
            isHovered: $isHovered,
            isPressed: $isPressed
        ) {
            action()
        }
    }
}
