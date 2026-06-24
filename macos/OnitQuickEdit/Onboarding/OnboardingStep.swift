//
//  OnboardingStep.swift
//  Onit
//
//  Created by Kévin Naudin on 28/11/2025.
//

import Defaults
import KeyboardShortcuts

@MainActor
enum OnboardingStep: String, CaseIterable, Codable, Defaults.Serializable {
    // MARK: - Step Cases

    /// Common Steps
    case featureSelection
    case permissions
    case discord

    /// Feature Step: QuickEdit
    case quickEditDemo

    /// Feature Step: QuickEdit Translation
    case quickEditTranslation

    case complete

    // MARK: - Feature-Specific Steps

    static let commonSteps: [OnboardingStep] = [
//        .featureSelection,
        .permissions,
        .discord
    ]

    static let quickEditSteps: [OnboardingStep] = [
        .quickEditDemo
    ]

    static let quickEditTranslationSteps: [OnboardingStep] = [
        .quickEditTranslation
    ]

    // MARK: - Onboarding Steps

    /// Builds the onboarding flow dynamically, based on enabled features.
    static var steps: [OnboardingStep] {
        /// Booleans
        let quickEditEnabled = Defaults[.quickEditConfig].isEnabled
        let quickEditTranslationEnabled = quickEditEnabled && Defaults[.isTranslationBuild]

        let mainOnboardingCompleted = Defaults[.mainOnboardingCompleted]

        let quickEditOnboardingCompleted = Defaults[.quickEditSpecificStepsCompleted]
        let quickEditTranslationOnboardingCompleted = Defaults[.quickEditTranslationSpecificStepsCompleted]

        /// Computations
        var result: [OnboardingStep] = []

        if quickEditEnabled && !quickEditOnboardingCompleted {
            result.append(contentsOf: quickEditSteps)
        }

        if !mainOnboardingCompleted {
            result.append(.permissions)
        }

        if quickEditTranslationEnabled && !quickEditTranslationOnboardingCompleted {
            result.append(contentsOf: quickEditTranslationSteps)
        }

        if !mainOnboardingCompleted {
            result.append(.discord)
        }

        result.append(.complete)

        return result
    }

    // MARK: - Navigation

    func nextStep() -> OnboardingStep? {
        let steps = Self.steps
        guard let currentStepIndex = steps.firstIndex(of: self) else { return nil }
        let nextStepIndex = currentStepIndex + 1
        return nextStepIndex < steps.count ? steps[nextStepIndex] : nil
    }

    func previousStep() -> OnboardingStep? {
        let steps = Self.steps
        guard let currentStepIndex = steps.firstIndex(of: self) else { return nil }
        let previousStepIndex = currentStepIndex - 1
        return previousStepIndex >= 0 ? steps[previousStepIndex] : nil
    }

    /// Returns the first step in the current flow that comes after the whole
    /// `quickEditSteps` group. Used to skip the QuickEdit-specific onboarding.
    /// Falls back to `.complete` when no step follows the group.
    static func firstStepAfterQuickEditSteps() -> OnboardingStep {
        let steps = Self.steps
        if let firstStepAfterGroup = steps.first(where: { !quickEditSteps.contains($0) }) {
            return firstStepAfterGroup
        }
        return .complete
    }

    // MARK: - Step Adjustment

    /// Returns a valid step when the current step belongs to a disabled feature.
    func getNextValidOnboardingStep() -> OnboardingStep? {
        if self == .complete {
            /// Check for feature-specific onboarding, even if main onboarding is complete/dismissed.
            if let firstStep = Self.steps.first,
               firstStep != .complete
            {
                return firstStep
            }
            /// Otherwise, onboarding complete. No adjustment needed.
            else {
                return .complete
            }
        }

        /// Currently in a valid step in the onboarding flow. No adjustment needed.
        if Self.steps.contains(self) {
            return self
        }

        /// If we've hit this point, it means we're in an invalid step.
        /// Redirect to the first valid step in the current flow.
        return Self.steps.first ?? .complete
    }

    // MARK: - Feature-Specific Helpers

    var isQuickEditSpecific: Bool {
        switch self {
        case .quickEditDemo, .quickEditTranslation:
            return true
        default:
            return false
        }
    }

    var isLastQuickEditStep: Bool {
        self == .quickEditDemo
    }

    var isFirstStep: Bool {
        self == Self.steps.first
    }

    /// Every step, other than the one `.complete` step, is conditional.
    /// If none of them exist in `OnboardingStep.steps`, it means that we shouldn't show the onboarding flow.
    /// Using `count`, in case future definitions of a "completed" onboarding change.
    static var isOnboardingComplete: Bool {
        return OnboardingStep.steps.count == 1
    }

    // MARK: - Display Properties

    var title: String {
        switch self {
        /// Common Steps
        case .featureSelection:
            return String.localized("Welcome to QuickEdit", table: "Onboarding")
        case .permissions:
            return String.localized("Grant access to unlock all tools", table: "Onboarding")
        case .discord:
            return String.localized("Join our Discord Server!", table: "Onboarding")

        /// Feature Step: QuickEdit
        case .quickEditDemo:
            return String.localized("Start by selecting text", table: "Onboarding")

        /// Feature Step: QuickEdit Translation
        case .quickEditTranslation:
            return String.localized("Set Up Translation", table: "Onboarding")

        case .complete:
            return String.localized("QuickEdit is up and running", table: "Onboarding")
        }
    }

    var caption: String {
        switch self {
        /// Common Steps
        case .featureSelection:
            return String.localized("Choose the features you want to enable.", table: "Onboarding")
        case .permissions:
            return "Permissions are needed for QuickEdit to work."
        case .discord:
            return String.localized("Say hello to the team and other Onit users, get updates\nand give feedback.", table: "Onboarding")

        /// Feature Step: QuickEdit
        case .quickEditDemo:
            return String.localized("Try it on the text below and see it go from messy to perfect!", table: "Onboarding")

        /// Feature Step: QuickEdit Translation
        case .quickEditTranslation:
            return String.localized("Choose your preferred languages for translation.", table: "Onboarding")

        case .complete:
            return String.localized("Select text in any app, and QuickEdit will polish it in a click.", table: "Onboarding")
        }
    }
}
