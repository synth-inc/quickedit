//
//  AnalyticsManager+Settings.swift
//  Onit
//
//  Created by Kévin Naudin on 21/05/2025.
//

import PostHog

extension AnalyticsManager {
    
    struct Settings {
        // MARK: - Auto-Install Updates

        /// Tracks when the auto-install updates toggle is changed
        /// - Parameter enabled: Whether auto-install is now enabled
        static func autoInstallUpdatesToggled(enabled: Bool) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["enabled"] = enabled

            PostHogSDK.shared.capture("settings_auto_install_updates_toggled", properties: properties)
        }
    }
}
