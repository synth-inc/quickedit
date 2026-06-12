//
//  AnalyticsManager+Referral.swift
//  Onit
//

import PostHog

extension AnalyticsManager {

    struct Referral {

        /// Tracks when a user applies a referrer code
        /// - Parameters:
        ///   - success: Whether the referrer code was applied successfully
        ///   - error: Error message if the application failed
        static func codeApplied(success: Bool, error: String? = nil) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["success"] = success
            if let error {
                properties["error"] = error
            }

            PostHogSDK.shared.capture("referral_code_applied", properties: properties)
        }

        /// Tracks when a user views the referral leaderboard
        static func leaderboardViewed() {
            AnalyticsManager.sendCommonEvent(event: "referral_leaderboard_viewed")
        }
    }
}
