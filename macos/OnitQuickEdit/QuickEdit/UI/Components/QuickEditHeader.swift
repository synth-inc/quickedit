//
//  QuickEditHeader.swift
//  Onit
//
//  Created by Loyd Kim on 11/24/25.
//

import SwiftUI

struct QuickEditHeader: View {
    // MARK: - Properties

    @ObservedObject var state: QuickEditState
    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Computed Properties
    
    private var displayTitle: String {
        guard let config = state.headerConfig else { return "" }
        
        if let key = config.localizationKey {
            return String.localized(key, table: "QuickEdit")
        }

        return config.title
    }

    // MARK: - Body

    var body: some View {
        if let config = state.headerConfig {
            HStack(alignment: .center, spacing: 4) {
                if let icon = config.icon {
                    Image(icon)
                        .addIconStyles(
                            foregroundColor: Color.T_1,
                            iconSize: config.iconSize
                        )
                } else if let sfSymbol = config.sfSymbol {
                    Image(systemName: sfSymbol)
                        .font(.system(size: config.iconSize))
                        .foregroundColor(Color.T_1)
                }

                Text(displayTitle)
                    .styleText(
                        size: 13,
                        color: config.isProminent ? Color.S_0 : Color.T_1
                    )
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(config.isProminent ? 8 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(config.isProminent ? Color.messageBG : Color.clear)
            .addBorder(
                cornerRadius: config.isProminent ? 8 : 0,
                stroke: config.isProminent ? Color.T_8 : Color.clear
            )
            .padding(.horizontal, 10)
            .id(localization.currentLanguage)
        }
    }
}
