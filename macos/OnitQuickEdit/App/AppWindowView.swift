//
//  AppWindowView.swift
//  Onit
//
//  Created by Loyd Kim on 4/28/26.
//

import SwiftUI

struct AppWindowView: View {
    // MARK: - Observations

    @ObservedObject private var localization = LocalizationManager.shared
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SettingsWindowSidebar()
            SettingsWindowPages()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(22)
        .ignoresSafeArea(.container, edges: .top)
        .id(localization.currentLanguage)
    }
}
