//
//  AnalyticsManager+Onboarding.swift
//  Onit
//
//  Created by Kévin Naudin on 22/05/2025.
//

import PostHog

extension AnalyticsManager {
    struct Onboarding {
        /// Tracks when the onboarding window is closed/dismissed
        /// - Parameters:
        ///   - step: The step the user was on when they dismissed
        ///   - completed: Whether onboarding was completed
        static func dismissed(step: String, completed: Bool) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["step"] = step
            properties["completed"] = completed

            PostHogSDK.shared.capture("onboarding_dismissed", properties: properties)
        }
    }
}
