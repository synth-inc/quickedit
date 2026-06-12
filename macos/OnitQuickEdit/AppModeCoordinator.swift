//
//  AppModeCoordinator.swift
//  Onit
//
//  Created by Kévin Naudin on 28/11/2025.
//

import Combine
import Defaults
import Foundation

/// Delegate protocol for AppModeCoordinator state changes
@MainActor
protocol AppModeCoordinatorDelegate: AnyObject {
    /// Called when QuickEdit mode state changes
    func appModeCoordinator(_ coordinator: AppModeCoordinator, didChangeQuickEditState enabled: Bool)
}

/// Centralized coordinator for managing app modes (QuickEdit)
/// Handles lifecycle, service dependencies, and state synchronization
@MainActor
final class AppModeCoordinator: ObservableObject {

    // MARK: - Shared Instance

    static let shared = AppModeCoordinator()

    // MARK: - Delegate

    weak var delegate: AppModeCoordinatorDelegate?

    // MARK: - State

    /// Current QuickEdit enabled state
    var isQuickEditEnabled: Bool {
        Defaults[.quickEditConfig].isEnabled
    }

    // MARK: - Services

    private var quickEditCancellable: AnyCancellable?

    // MARK: - Initialization

    private init() {
        setupObservers()

        // Defer initialization of enabled features to next run loop
        // (observers use dropFirst, so they won't trigger for initial values)
        DispatchQueue.main.async { [weak self] in
            self?.initializeEnabledFeaturesAtStartup()
        }
    }

    /// Initialize features that were already enabled before app launch
    private func initializeEnabledFeaturesAtStartup() {
        if isQuickEditEnabled {
            startQuickEdit()
        }
    }

    // MARK: - Public Interface

    /// Cleanup resources on app termination
    func cleanup() {
        quickEditCancellable?.cancel()
        if isQuickEditEnabled {
            self.stopQuickEdit()
        }
    }

    // MARK: - QuickEdit Control

    /// Enable QuickEdit mode
    func enableQuickEdit() {
        guard !isQuickEditEnabled else { return }
        var config = Defaults[.quickEditConfig]
        config.isEnabled = true
        Defaults[.quickEditConfig] = config
    }

    /// Disable QuickEdit mode
    func disableQuickEdit() {
        guard isQuickEditEnabled else { return }
        var config = Defaults[.quickEditConfig]
        config.isEnabled = false
        Defaults[.quickEditConfig] = config
    }

    // MARK: - Private Helpers

    private func setupObservers() {
        // Observer for QuickEdit state changes
        quickEditCancellable = Defaults.publisher(.quickEditConfig)
            .map(\.newValue.isEnabled)
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                Task { @MainActor in
                    guard let self = self else { return }
                    if enabled {
                        self.startQuickEdit()
                    } else {
                        self.stopQuickEdit()
                    }
                    self.delegate?.appModeCoordinator(self, didChangeQuickEditState: enabled)
                }
            }
    }

    private func startQuickEdit() {
        launchOnboardingIfNeeded()
        QuickEditManager.shared.startListening()
    }

    private func stopQuickEdit() {
        closeOnboardingIfNeeded()
        QuickEditManager.shared.stopListening()
    }

    // MARK: - Onboarding Helpers

    /// Launches onboarding if not dismissed and not completed
    func launchOnboardingIfNeeded() {
        let onboardingDismissed = Defaults[.onboardingDismissed]
        let currentStep = Defaults[.currentOnboardingStep]

        // Safety check: if onboarding was marked as dismissed but step is not complete,
        // it means the app was force-quit.
        // Reset the dismissed flag to allow onboarding to resume.
        if onboardingDismissed && currentStep != .complete {
            Defaults[.onboardingDismissed] = false
        }

        // Safety check: if current step belongs to a disabled feature, skip to an appropriate step
        Defaults[.currentOnboardingStep] = currentStep?.getNextValidOnboardingStep()

        guard !OnboardingStep.isOnboardingComplete else { return }

        OnboardingWindowManager.shared.showWindow()
    }

    private func closeOnboardingIfNeeded() {
        if OnboardingStep.isOnboardingComplete {
            OnboardingWindowManager.shared.closeWindow()
        }
    }
}
