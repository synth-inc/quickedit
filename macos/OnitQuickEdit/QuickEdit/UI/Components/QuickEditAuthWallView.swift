//
//  QuickEditAuthWallView.swift
//  Onit
//
//  Created by Kévin Naudin on 12/04/25.
//

import SwiftUI

/// View displayed when user is not logged in and tries to use QuickEdit.
/// Shows blurred text preview and a card prompting to sign in.
struct QuickEditAuthWallView: View {

    // MARK: - Observed Objects

    @ObservedObject private var localization = LocalizationManager.shared

    // MARK: - Properties

    let originalText: String
    let source: QuickEditMode?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            BlurredTextPreview(
                text: originalText,
                blurRadius: 6,
                lineLimit: 6
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            DividerHorizontal()

            authWallContent
        }
        .onAppear {
            AnalyticsManager.QuickEdit.authWallShown(source: sourceString)
        }
        .id(localization.currentLanguage)
    }

    // MARK: - Content

    private var authWallContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String.localized("Sign in to use QuickEdit", table: "QuickEdit"))
                .styleText(size: 16, weight: .bold)

            Text(String.localized("Create a free account to get started with AI-powered text editing.", table: "QuickEdit"))
                .styleText(size: 12, weight: .medium, color: Color.T_1)
                .padding(.bottom, 4)

            PaywallCTAButton(
                text: String.localized("Sign in", table: "QuickEdit"),
                action: handleSignInCTA
            )
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed Properties

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

    // MARK: - Actions

    private func handleSignInCTA() {
        AnalyticsManager.QuickEdit.authWallCTAClicked(source: sourceString)

        QuickEditManager.shared.hideForAuth()

        OnboardingWindowManager.shared.showAuthOnly()
    }
}
