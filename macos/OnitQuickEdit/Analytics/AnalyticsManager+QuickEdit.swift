//
//  AnalyticsManager+QuickEdit.swift
//  Onit
//
//  Created by Kévin Naudin on 11/27/2025.
//

import Foundation
import PostHog

extension AnalyticsManager {

    struct QuickEdit {

        // MARK: - Model Picker Events

        struct ModelPicker {

            static func opened(source: String) {
                var properties = AnalyticsManager.getCommonProperties()
                properties["source"] = source  // "Settings", "QuickEdit"

                PostHogSDK.shared.capture("quick_edit_model_picker_opened", properties: properties)
            }

            static func settingsPressed(source: String) {
                var properties = AnalyticsManager.getCommonProperties()
                properties["source"] = source

                PostHogSDK.shared.capture("quick_edit_model_picker_settings", properties: properties)
            }

            static func modelSelected(source: String, mode: String, model: String) {
                var properties = AnalyticsManager.getCommonProperties()
                properties["source"] = source
                properties["llm_mode"] = mode
                properties["llm_model"] = model

                PostHogSDK.shared.capture("quick_edit_model_picker_selected", properties: properties)
            }

            static func localSetupPressed(source: String) {
                var properties = AnalyticsManager.getCommonProperties()
                properties["source"] = source

                PostHogSDK.shared.capture("quick_edit_model_picker_local_setup", properties: properties)
            }
        }

        // MARK: - Hint Events

        static func hintShown() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_hint_shown")
        }

        static func hintClicked() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_hint_clicked")
        }

        // MARK: - QuickEdit Events

        static func opened(trigger: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["trigger"] = trigger  // "hint", "keyboard_shortcut", "menu"

            PostHogSDK.shared.capture("quick_edit_opened", properties: properties)
        }

        static func closed(reason: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["reason"] = reason  // "user_cancelled", "completed", "error"

            PostHogSDK.shared.capture("quick_edit_closed", properties: properties)
        }

        // MARK: - Generation Events

        static func generationStarted(mode: String, model: String, inputLength: Int) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["llm_mode"] = mode  // "remote", "local"
            properties["llm_model"] = model
            properties["input_length"] = inputLength

            PostHogSDK.shared.capture("quick_edit_generation_started", properties: properties)
        }

        static func generationCompleted(mode: String, model: String, duration: TimeInterval, outputLength: Int) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["llm_mode"] = mode
            properties["llm_model"] = model
            properties["duration_ms"] = Int(duration * 1000)
            properties["output_length"] = outputLength

            PostHogSDK.shared.capture("quick_edit_generation_completed", properties: properties)
        }

        static func generationFailed(mode: String, model: String, error: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["llm_mode"] = mode
            properties["llm_model"] = model
            properties["error"] = error

            PostHogSDK.shared.capture("quick_edit_generation_failed", properties: properties)
        }

        // MARK: - User Feedback Events

        static func resultAccepted() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_result_accepted")
        }

        static func resultRejected() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_result_rejected")
        }

        // MARK: - Paywall Events

        /// Tracks when a paywall is shown to the user
        /// - Parameters:
        ///   - paywallType: "free_limit" or "pro_limit"
        ///   - source: "improve" or "prompt"
        static func paywallShown(paywallType: String, source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["paywall_type"] = paywallType
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_paywall_shown", properties: properties)
        }

        /// Tracks when a user clicks a CTA button on the paywall
        /// - Parameters:
        ///   - paywallType: "free_limit" or "pro_limit"
        ///   - ctaType: "start_trial", "upgrade", or "request_more"
        ///   - source: "improve" or "prompt"
        static func paywallCTAClicked(paywallType: String, ctaType: String, source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["paywall_type"] = paywallType
            properties["cta_type"] = ctaType
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_paywall_cta_clicked", properties: properties)
        }

        /// Tracks when a user successfully converts (subscribes/upgrades) from the paywall
        /// - Parameters:
        ///   - paywallType: "free_limit" or "pro_limit"
        ///   - source: "improve" or "prompt"
        static func paywallConversion(paywallType: String, source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["paywall_type"] = paywallType
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_paywall_conversion", properties: properties)
        }

        // MARK: - Auth Wall Events

        /// Tracks when an auth wall is shown to the user (not logged in)
        /// - Parameter source: "improve" or "prompt"
        static func authWallShown(source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_auth_wall_shown", properties: properties)
        }

        /// Tracks when a user clicks the sign in CTA on the auth wall
        /// - Parameter source: "improve" or "prompt"
        static func authWallCTAClicked(source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_auth_wall_cta_clicked", properties: properties)
        }

        /// Tracks when a user successfully signs in from the auth wall
        /// - Parameter source: "improve" or "prompt"
        static func authWallConversion(source: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["source"] = source

            PostHogSDK.shared.capture("quick_edit_auth_wall_conversion", properties: properties)
        }

        // MARK: - Onboarding Events

        /// Tracks when the QuickEdit auth onboarding step is shown
        static func onboardingAuthShown() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_auth_shown")
        }

        /// Tracks when the user successfully completes authentication during onboarding
        /// - Parameter provider: "google", "email", or "apple"
        static func onboardingAuthCompleted(provider: String) {
            var properties = AnalyticsManager.getCommonProperties()
            properties["provider"] = provider

            PostHogSDK.shared.capture("quick_edit_onboarding_auth_completed", properties: properties)
        }

        /// Tracks when the QuickEdit intro onboarding step is shown
        static func onboardingIntroShown() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_intro_shown")
        }

        /// Tracks when the user skips the QuickEdit intro page during onboarding
        static func onboardingIntroSkipped() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_intro_skipped")
        }

        /// Tracks when the QuickEdit demo onboarding step is shown
        static func onboardingDemoShown() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_demo_shown")
        }

        /// Tracks when the QuickEdit demo is completed
        static func onboardingDemoCompleted() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_demo_completed")
        }

        /// Tracks when the user skips the QuickEdit demo
        static func onboardingDemoSkipped() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_demo_skipped")
        }

        /// Tracks when the QuickEdit permissions onboarding step is shown
        static func onboardingPermissionsShown() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_permissions_shown")
        }

        /// Tracks when the user completes the permissions step during onboarding
        static func onboardingPermissionsCompleted() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_permissions_completed")
        }

        /// Tracks when accessibility permission is granted during onboarding
        static func onboardingAccessibilityGranted() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_accessibility_granted")
        }

        /// Tracks when screen recording permission is granted during onboarding
        static func onboardingScreenRecordingGranted() {
            AnalyticsManager.sendCommonEvent(event: "quick_edit_onboarding_screen_recording_granted")
        }
    }
}
