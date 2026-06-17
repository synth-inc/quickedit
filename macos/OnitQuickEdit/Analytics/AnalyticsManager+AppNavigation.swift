//
//  AnalyticsManager+AppNavigation.swift
//  Onit
//
//  Created by Tim on 5/9/26.
//

import PostHog

extension AnalyticsManager {

    struct AppNavigation {

        /// Tracks when the App window is opened (shown/created).
        static func appWindowOpened() {
            AnalyticsManager.sendCommonEvent(event: "app_window_opened")
        }
    }
}
