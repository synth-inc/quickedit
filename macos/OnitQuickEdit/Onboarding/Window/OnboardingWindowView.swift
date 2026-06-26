//
//  OnboardingWindowView.swift
//  Onit
//
//  Created by Kévin Naudin on 28/11/2025.
//

import Defaults
import SwiftUI

struct OnboardingWindowView: View {
    // MARK: - Defaults

    @Default(.currentOnboardingStep) var currentStep
    @Default(.quickEditConfig) var quickEditConfig
    @Default(.isTranslationBuild) var isTranslationBuild
    @Default(.onboardingAuthSkipped) var onboardingAuthSkipped

    // MARK: - Properties

    @ObservedObject private var localization = LocalizationManager.shared
    private let windowManager = OnboardingWindowManager.shared

    // MARK: - States

    @ObservedObject private var authManager = AuthManager.shared

    // MARK: - Private Variables

    private var quickEditEnabled: Bool {
        return quickEditConfig.isEnabled
    }

    private var quickEditTranslationEnabled: Bool {
        return quickEditEnabled && isTranslationBuild
    }

    // MARK: - Body

    var body: some View {
        windowPage
            .id(localization.currentLanguage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Backgrounds.BrushedGlass())
            .cornerRadius(22)
            .ignoresSafeArea(.container, edges: .top)
            .onChange(of: authManager.userLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    if windowManager.authOnly {
                        windowManager.closeWindow()
                    } else if currentStep == nil {
                        updateToValidStepView()
                    }
                }
            }
            .onChange(of: self.currentStep) { previousStep, currentStep in
                markFeatureOnboardingAsCompletedIfNeeded(
                    previousStep,
                    currentStep
                )

                if currentStep == .complete {
                    handleOnboardingComplete()
                }
            }
            .onChange(of: quickEditEnabled) { _, _ in
                updateToValidStepView()
            }
    }

    // MARK: - Child Components

    @ViewBuilder
    private var windowPage: some View {
        if authManager.isRestoringSession {
            // Blank during session restore (brief) — no loading page, and avoids
            // flashing the auth page before the restored session resolves.
            EmptyView()
        } else if !authManager.userLoggedIn && (!onboardingAuthSkipped || windowManager.authOnly) {
            OnboardingQuickEditAuth()
        } else if let currentStep = self.currentStep {
            switch currentStep {
            /// Common Steps
            case .featureSelection:
                OnboardingFeatureSelection()
            case .permissions:
                OnboardingPermissions()

            /// Feature Step: QuickEdit
            case .quickEditDemo:
                OnboardingQuickEditDemo()

            /// Feature Step: QuickEdit Translation
            case .quickEditTranslation:
                OnboardingTranslation()

            case .complete:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Private Functions

    private func updateToValidStepView() {
        currentStep = OnboardingStep.steps.first
    }

    private func getStepIndexes(
        _ previousStep: OnboardingStep,
        _ currentStep: OnboardingStep
    ) -> (
        previousStepIndex: Int,
        currentStepIndex: Int
    )? {
        guard let previousStepIndex = OnboardingStep.steps.firstIndex(of: previousStep),
              let currentStepIndex = OnboardingStep.steps.firstIndex(of: currentStep)
        else {
            return nil
        }

        return (
            previousStepIndex: previousStepIndex,
            currentStepIndex: currentStepIndex
        )
    }

    private func didCrossOverLastStepOfFeatureOnboarding(
        for lastStepIndex: Int,
        _ previousStepIndex: Int,
        _ currentStepIndex: Int
    ) -> Bool {
        return previousStepIndex <= lastStepIndex && currentStepIndex > lastStepIndex
    }

    private func markFeatureOnboardingAsCompletedIfNeeded(
        _ previousStep: OnboardingStep?,
        _ currentStep: OnboardingStep?
    ) {
        guard let previousStep = previousStep,
              let currentStep = currentStep,
              let (previousStepIndex, currentStepIndex) = getStepIndexes(previousStep, currentStep)
        else {
            return
        }

        let didNavigateForward = currentStepIndex > previousStepIndex
        guard didNavigateForward else { return }

        let steps = OnboardingStep.steps

        /// QuickEdit
        if quickEditEnabled,
           let lastQuickEditStep = OnboardingStep.quickEditSteps.last,
           let lastQuickEditStepIndex = steps.firstIndex(of: lastQuickEditStep),
           didCrossOverLastStepOfFeatureOnboarding(
                for: lastQuickEditStepIndex,
                previousStepIndex,
                currentStepIndex
           )
        {
            Defaults[.quickEditSpecificStepsCompleted] = true
        }

        /// QuickEdit Translation
        if quickEditTranslationEnabled,
           let lastQuickEditTranslationStep = OnboardingStep.quickEditTranslationSteps.last,
           let lastQuickEditTranslationStepIndex = steps.firstIndex(of: lastQuickEditTranslationStep),
           didCrossOverLastStepOfFeatureOnboarding(
                for: lastQuickEditTranslationStepIndex,
                previousStepIndex,
                currentStepIndex
           )
        {
            Defaults[.quickEditTranslationSpecificStepsCompleted] = true
        }
    }

    private func handleOnboardingComplete() {
        if !Defaults[.mainOnboardingCompleted] {
            NotificationWindowManager.shared.createWindow(
                titleKey: String.localized("QuickEdit is up and running!", table: "Onboarding"),
                captionKey: String.localized("You're all set to use QuickEdit.", table: "Onboarding"),
                primaryAction: (
                    textKey: String.localized("Ok", table: "Onboarding"),
                    shouldCloseWindow: true,
                    callback: nil
                ),
                enterAnimation: NotificationWindowAnimation(direction: .right),
                dismissAnimation: NotificationWindowAnimation(direction: .right)
            )

            Defaults[.mainOnboardingCompleted] = true
        }

        windowManager.closeWindow()
    }
}
