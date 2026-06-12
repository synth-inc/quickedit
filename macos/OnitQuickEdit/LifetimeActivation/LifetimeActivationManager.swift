//
//  LifetimeActivationManager.swift
//  Onit
//
//  Created by Loyd Kim on 4/8/26.
//

import Foundation

@MainActor
final class LifetimeActivationManager: ObservableObject {
    // MARK: - Singleton

    static let shared = LifetimeActivationManager()

    private init() {}

    // MARK: - Published Properties

    @Published private(set) var activation: LifetimeActivation? = nil
    @Published private(set) var stats: LifetimeActivationStats? = nil

    @Published private(set) var isFetchingActivation: Bool = false
    @Published private(set) var isFetchingStats: Bool = false
    @Published private(set) var isClaimingActivation: Bool = false

    @Published private(set) var claimActivationFailed: Bool = false

    // MARK: - Public Methods: Reset

    func reset() {
        activation = nil
        stats = nil
        isFetchingActivation = false
        isFetchingStats = false
        isClaimingActivation = false
        claimActivationFailed = false
    }

    // MARK: - Public Methods: Fetching

    func fetchStats() async {
        isFetchingStats = true

        do {
            let client = FetchingClient()
            stats = try await client.getLifetimeActivationStats(productName: .dictation)
        } catch {
            print("[LifetimeActivationManager]: Failed to fetch lifetime activation stats: \(error.localizedDescription)")
            stats = nil
        }

        isFetchingStats = false
    }

    func fetchActivation() async {
        guard AuthManager.shared.userLoggedIn else {
            activation = nil
            return
        }

        isFetchingActivation = true

        do {
            let client = FetchingClient()
            let result = try await client.getLifetimeActivation(productName: .dictation)
            guard AuthManager.shared.userLoggedIn else { return }
            activation = result
        } catch {
            print("[LifetimeActivationManager]: Failed to fetch lifetime activation: \(error.localizedDescription)")
            AnalyticsManager.LifetimeActivations.activationFetchFailed(error: error.localizedDescription)
            activation = nil
        }

        isFetchingActivation = false
    }

    func claimActivation() async {
        guard AuthManager.shared.userLoggedIn else { return }

        isClaimingActivation = true
        claimActivationFailed = false

        do {
            let client = FetchingClient()
            activation = try await client.createLifetimeActivation(productName: .dictation)
        } catch {
            print("[LifetimeActivationManager]: Failed to claim lifetime activation: \(error.localizedDescription)")
            AnalyticsManager.LifetimeActivations.activationClaimFailed(error: error.localizedDescription)
            claimActivationFailed = true
        }

        isClaimingActivation = false
    }
}
