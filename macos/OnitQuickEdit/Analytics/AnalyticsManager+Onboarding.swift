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

        /// Tracks when the Discord step is shown
        static func discordShown() {
            AnalyticsManager.sendCommonEvent(event: "onboarding_discord_shown")
        }

        /// Tracks when user accepts the Discord invite
        static func discordAccepted() {
            AnalyticsManager.sendCommonEvent(event: "onboarding_discord_accepted")
        }

        /// Tracks when user skips the Discord step
        static func discordSkipped() {
            AnalyticsManager.sendCommonEvent(event: "onboarding_discord_skipped")
        }
    }
}
