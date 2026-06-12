//
//  QuickEditAccessService.swift
//  Onit
//
//  Created by Kévin Naudin on 12/03/25.
//

import Defaults
import Foundation

/// Service responsible for checking access (auth + paywall) and simulating generation
/// when the user needs to authenticate or has exceeded their quota.
@MainActor
class QuickEditAccessService {

    // MARK: - Singleton

    static let shared = QuickEditAccessService()

    // MARK: - Dependencies

    private let authManager = AuthManager.shared
    private let appState = AppState.shared
    private let modelProvidersManager = ModelProvidersManager.shared

    // MARK: - Access Check

    /// Result of an access check (auth + paywall)
    struct AccessCheckResult {
        let requiresAuth: Bool
        let shouldShowPaywall: Bool
        let paywallType: QuickEditPaywallType?

        static let allowed = AccessCheckResult(requiresAuth: false, shouldShowPaywall: false, paywallType: nil)
        static let authRequired = AccessCheckResult(requiresAuth: true, shouldShowPaywall: false, paywallType: nil)

        static func paywall(_ type: QuickEditPaywallType) -> AccessCheckResult {
            AccessCheckResult(requiresAuth: false, shouldShowPaywall: true, paywallType: type)
        }
    }

    // DEBUG: Set to .freeLimit or .proLimit to test paywall, nil for normal behavior
//    private let debugForcePaywall: QuickEditPaywallType? = .freeLimit
    // DEBUG: Number of generations to allow before forcing paywall (0 = force immediately)
//    private let debugAllowedGenerationsBeforePaywall: Int = 1
//    private var debugGenerationCount: Int = 0

    /// Checks if the user can generate or needs auth/paywall.
    /// - Returns: An `AccessCheckResult` indicating what action is needed.
    func checkAccess() async -> AccessCheckResult {
        // DEBUG: Force paywall for testing after N generations
        // TIM Note: this is very helpful, so I'm leaving it in!
//        if let paywallType = debugForcePaywall {
//            if debugGenerationCount >= debugAllowedGenerationsBeforePaywall {
//                return .paywall(paywallType)
//            }
//            debugGenerationCount += 1
//        }

        // 1. Check if user has API key for current QuickEdit model - bypass all checks
        if checkApiKeyExistsForQuickEditModel() {
            return .allowed
        }

        // 2. If user is not logged in, they need to authenticate
        guard authManager.userLoggedIn else {
            return .authRequired
        }

        // 3. Fetch usage from API
        do {
            let client = FetchingClient()
            guard let chatUsage = try await client.getChatUsage() else {
                // If we can't fetch usage, fail open (allow generation)
                return .allowed
            }

            let usage = chatUsage.usage
            let quota = chatUsage.quota
            let exceededLimit = usage >= quota

            guard exceededLimit else {
                // User has quota remaining
                return .allowed
            }

            // 4. Determine paywall type based on subscription status
            let paywallType = determinePaywallType()
            
            return .paywall(paywallType)

        } catch {
            print("[QuickEditAccessService] Failed to fetch usage: \(error)")
            return .allowed
        }
    }

    // MARK: - Simulation

    /// Simulates a generation with appropriate timing based on the model.
    /// - Parameters:
    ///   - text: The original text to simulate generating
    ///   - onStateChange: Callback to update the generation state
    ///   - onTextProgress: Callback to update the simulated text (for streaming simulation)
    func simulateGeneration(
        text: String,
        onStateChange: @escaping (GenerationState) -> Void,
        onTextProgress: @escaping (String) -> Void
    ) async {
        let isStreaming = shouldUseStream()
        let textLength = text.count
        
        onStateChange(.starting)
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        onStateChange(.generating)
        
        let duration = calculateSimulationDuration(textLength: textLength)
        
        if isStreaming {
            await simulateStreamingText(
                text: text,
                duration: duration,
                onTextProgress: onTextProgress
            )
        } else {
            let nanoseconds = UInt64(duration * 1_000_000_000)
            
            try? await Task.sleep(nanoseconds: nanoseconds)
            
            onTextProgress(text)
        }
        
        onStateChange(.done)
    }

    /// Simulates streaming text by revealing it progressively over the duration
    private func simulateStreamingText(
        text: String,
        duration: TimeInterval,
        onTextProgress: @escaping (String) -> Void
    ) async {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        guard !words.isEmpty else {
            onTextProgress(text)
            return
        }
        
        let delayPerWord = duration / Double(words.count)
        let nanosecondsPerWord = UInt64(delayPerWord * 1_000_000_000)
        
        var currentText = ""
        for (index, word) in words.enumerated() {
            if index > 0 {
                currentText += " "
            }
            currentText += word
            onTextProgress(currentText)
            
            if index < words.count - 1 {
                try? await Task.sleep(nanoseconds: nanosecondsPerWord)
            }
        }
    }

    /// Determines if the current QuickEdit model uses streaming
    private func shouldUseStream() -> Bool {
        let inferenceMode = Defaults[.quickEditMode]
        let streamConfig = Defaults[.streamResponse]

        switch inferenceMode {
        case .local:
            return streamConfig.local
        case .remote:
            guard let model = Defaults[.quickEditRemoteModel] else {
                return true
            }

            switch model.provider {
            case .openAI:
                return streamConfig.openAI
            case .anthropic:
                return streamConfig.anthropic
            case .deepSeek:
                return streamConfig.deepSeek
            case .googleAI:
                return streamConfig.googleAI
            case .perplexity:
                return streamConfig.perplexity
            case .xAI:
                return streamConfig.xAI
            case .cerebras:
                return streamConfig.cerebras
            case .custom:
                if let customProviderName = model.customProviderName {
                    return streamConfig.customProviders[customProviderName] ?? true
                }
                return true
            }
        }
    }

    // MARK: - Private Helpers

    /// Checks if the user has provided an API key for the current QuickEdit model.
    private func checkApiKeyExistsForQuickEditModel() -> Bool {
        let inferenceMode = Defaults[.quickEditMode]

        guard inferenceMode == .remote else { return true }
        guard let model = Defaults[.quickEditRemoteModel] else {
            return false
        }

        if model.provider == .custom {
            return true
        }

        return modelProvidersManager.getHasValidRemoteProviderToken(provider: model.provider)
    }

    /// Determines which type of paywall to show based on subscription status.
    private func determinePaywallType() -> QuickEditPaywallType {
        // Pro users who exceeded limit
        if appState.subscriptionStatus == SubscriptionStatus.active {
            return .proLimit
        }

        // Free/trialing users or any other status
        return .freeLimit
    }

    /// Calculates the simulation duration based on model type and text length.
    /// - Parameter textLength: Length of the selected text
    /// - Returns: Duration in seconds
    private func calculateSimulationDuration(textLength: Int) -> TimeInterval {
        let inferenceMode = Defaults[.quickEditMode]
        let model = Defaults[.quickEditRemoteModel]

        // Check if using a fast model (Cerebras GPT OSS)
        let isFastModel = inferenceMode == .remote && model?.provider == .cerebras

        if isFastModel {
            // Fast models: 0.1s to 0.3s based on text length
            let baseDuration = 0.1
            let maxDuration = 0.3
            let lengthFactor = min(Double(textLength) / 500.0, 1.0)
            return baseDuration + (maxDuration - baseDuration) * lengthFactor
        } else {
            // Other models: 2s to 4s based on text length
            let baseDuration = 2.0
            let maxDuration = 4.0
            let lengthFactor = min(Double(textLength) / 500.0, 1.0)
            return baseDuration + (maxDuration - baseDuration) * lengthFactor
        }
    }
}
