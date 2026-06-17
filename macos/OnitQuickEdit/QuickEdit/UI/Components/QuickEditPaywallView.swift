//
//  QuickEditPaywallView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/03/25.
//

import SwiftUI

/// Paywall view that shows animated blurred text with the paywall card always visible
struct QuickEditPaywallView: View {

    // MARK: - Environment

    @Environment(\.openURL) var openURL

    // MARK: - Dependencies

    @ObservedObject private var stripeManager = StripeManager.shared
    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Properties

    let simulatedText: String
    let paywallType: QuickEditPaywallType
    let source: QuickEditMode?

    // MARK: - State

    @State private var freeTrialAvailable: Bool?
    @State private var isCheckingTrial: Bool = false
    @State private var isActionLoading: Bool = false
    @State private var didOpenStripe: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            BlurredTextPreview(
                text: simulatedText.isEmpty ? " " : simulatedText,
                blurRadius: 6,
                lineLimit: 6
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            DividerHorizontal()

            paywallContent
        }
        .onAppear {
            // Track paywall shown
            AnalyticsManager.QuickEdit.paywallShown(
                paywallType: paywallTypeString,
                source: sourceString
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard didOpenStripe else { return }
            didOpenStripe = false

            Task {
                await checkSubscriptionAndDismissIfNeeded()
            }
        }
        .id(localization.currentLanguage)
    }

    // MARK: - Subscription Check

    /// Checks if user now has quota available and dismisses paywall if so
    private func checkSubscriptionAndDismissIfNeeded() async {
        // Refresh subscription data
        await stripeManager.fetchSubscriptionData()

        // Re-check paywall status
        let result = await QuickEditAccessService.shared.checkAccess()

        // If user no longer needs paywall, dismiss and retry generation
        if !result.shouldShowPaywall {
            QuickEditManager.shared.retryAfterSuccessfulSubscription()
        }
    }

    // MARK: - Paywall Content

    @ViewBuilder
    private var paywallContent: some View {
        Group {
            switch paywallType {
            case .freeLimit:
                freeLimitPaywall
            case .proLimit:
                proLimitPaywall
            }
        }
    }

    private var freeLimitPaywall: some View {
        VStack(spacing: 8) {
            PaywallCard(
                config: PaywallCardConfig(
                    title: String.localized("You're out of free edits.", table: "QuickEdit"),
                    description: String.localized("Unlock more with a %@", table: "QuickEdit", freeTrialAvailable == true ? String.localized("free trial!", table: "QuickEdit") : String.localized("Pro membership!", table: "QuickEdit")),
                    ctaText: ctaButtonText,
                    ctaAction: handleFreeLimitCTA,
                    ctaIsLoading: isActionLoading || isCheckingTrial
                )
            )
            .task {
                await checkTrialAvailability()
            }

            // KEVIN: Usefull to test the fragment-based operation when subscription succeeded
            #if DEBUG
            Button("DEBUG: Simulate Subscription Success") {
                QuickEditManager.shared.retryAfterSuccessfulSubscription()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            #endif
        }
    }

    private var proLimitPaywall: some View {
        PaywallCard(
            config: .proLimit(onCTATapped: handleProLimitCTA)
        )
    }

    // MARK: - Computed Properties

    private var ctaButtonText: String {
        if isCheckingTrial {
            return String.localized("Loading...", table: "QuickEdit")
        }
        return freeTrialAvailable == true ? String.localized("Unlock for $0", table: "QuickEdit") : String.localized("Upgrade to Pro", table: "QuickEdit")
    }

    private var sourceString: String {
        switch source {
        case .improve:
            return "improve"
        case .prompt:
            return "prompt"
        case .none:
            return "unknown"
        }
    }

    private var paywallTypeString: String {
        paywallType == .freeLimit ? "free_limit" : "pro_limit"
    }

    // MARK: - Actions

    private func checkTrialAvailability() async {
        isCheckingTrial = true
        
        let (available, _) = await Stripe.checkFreeTrialAvailable()
        
        freeTrialAvailable = available
        isCheckingTrial = false
    }

    private func handleFreeLimitCTA() {
        // Track analytics
        if freeTrialAvailable == true {
            AnalyticsManager.Billing.startFreeTrialPressed()
            AnalyticsManager.QuickEdit.paywallCTAClicked(
                paywallType: "free_limit",
                ctaType: "start_trial",
                source: sourceString
            )
        } else {
            AnalyticsManager.Billing.upgradeProPressed()
            AnalyticsManager.QuickEdit.paywallCTAClicked(
                paywallType: "free_limit",
                ctaType: "upgrade",
                source: sourceString
            )
        }

        Task {
            isActionLoading = true
            didOpenStripe = true
            _ = await Stripe.openSubscriptionForm(openURL)
            isActionLoading = false
        }
    }

    private func handleProLimitCTA() {
        AnalyticsManager.QuickEdit.paywallCTAClicked(
            paywallType: "pro_limit",
            ctaType: "request_more",
            source: sourceString
        )

        if let emailURL = URL(string: "mailto:contact@getonit.ai?subject=Request%20More%20Edits") {
            openURL(emailURL)
        }
    }
}
