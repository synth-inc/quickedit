//
//  GeneratingShimmerView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/10/2025.
//

import SwiftUI

struct GeneratingShimmerView: View {
    
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var textColor: Color {
        isLightMode ? Color.black : Color.white
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(textColor.opacity(0.15))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .shimmering()

                RoundedRectangle(cornerRadius: 4)
                    .fill(textColor.opacity(0.15))
                    .frame(width: 180, height: 12)
                    .shimmering()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ShimmerLineView

/// A single shimmer bar that matches the exact size of a text line
struct ShimmerLineView: View {
    let rect: CGRect

    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var fillColor: Color {
        isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.15)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fillColor)
            .frame(width: rect.width, height: rect.height)
            .shimmering()
            // Position the center of the view at the center of the rect
            .position(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
    }
}
