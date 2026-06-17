//
//  UnfreezeHintView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import SwiftUI

/// View for the Un-freeze hint shown when clicking on frozen text
struct UnfreezeHintView: View {

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Observed Objects

    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Properties

    let showUnfreezeAll: Bool
    let onUnfreeze: () -> Void
    let onUnfreezeAll: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            HintActionButton(
                icon: .freezeCross,
                text: String.localized("Un-freeze", table: "QuickEdit"),
                action: onUnfreeze
            )

            if showUnfreezeAll {
                divider

                HintActionButton(
                    icon: .freezeCross,
                    text: String.localized("Un-freeze all", table: "QuickEdit"),
                    action: onUnfreezeAll
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .fixedSize()
        .background(Backgrounds.BrushedGlass())
        .cornerRadius(9)
        .addBorder(cornerRadius: 9, stroke: Color.T_7)
        .id(localization.currentLanguage)
    }

    // MARK: - Child Components

    private var divider: some View {
        Rectangle()
            .fill(Color.S_0.opacity(0.2))
            .frame(width: 1, height: 16)
    }
}
