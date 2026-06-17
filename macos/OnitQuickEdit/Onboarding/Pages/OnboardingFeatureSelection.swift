//
//  OnboardingFeatureSelection.swift
//  Onit
//
//  Created by Kévin Naudin on 28/11/2025.
//

import Defaults
import SwiftUI

struct OnboardingFeatureSelection: View {
    // MARK: - Defaults

    @Default(.currentOnboardingStep) var currentStep
    @Default(.quickEditConfig) var quickEditConfig

    // MARK: - Body

    var body: some View {
        OnboardingPage(
            headerConfig: .init(paddingTop: 40),
            footerConfig: .init(
                showBackButton: false,
                showNextButton: false
            ),
            headerContent: {
                logoView
            },
            headerTitle: { EmptyView() },
            bodyContent: {
                VStack(alignment: .center, spacing: 24) {
                    titleAndCaption

                    featureToggles
                }
            },
            footerContent: {
                HStack(alignment: .center) {
                    OnboardingFooterDocumentationLinks()

                    Spacer()

                    OnboardingEnterButton(
                        text: String.localized("Start Setup →", table: "Onboarding")
                    )
                }
            }
        )
    }

    // MARK: - Child Components

    private var logoView: some View {
        Image(.logo)
            .resizable()
            .frame(
                width: 86,
                height: 86
            )
            .padding(.bottom, 20)
    }

    private var titleAndCaption: some View {
        VStack(alignment: .center, spacing: 11) {
            if let title = currentStep?.title {
                Text(title)
                    .styleText(
                        size: 37,
                        weight: .semibold,
                        align: .center
                    )
                    .opacity(0.8)
            }
            
            if let caption = currentStep?.caption {
                Text(caption)
                    .styleText(
                        size: 21,
                        weight: .regular,
                        color: Color.S_1,
                        align: .center
                    )
            }
        }
    }

    private var featureToggles: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureToggle(
                title: String.localized("QuickEdit", table: "Onboarding"),
                description: String.localized("Instant AI text improvements with one click", table: "Onboarding"),
                isEnabled: Binding(
                    get: { quickEditConfig.isEnabled },
                    set: { newValue in
                        var config = quickEditConfig
                        config.isEnabled = newValue
                        quickEditConfig = config
                    }
                )
            )

        }
        .frame(width: 400)
    }

    private func featureToggle(
        title: String,
        description: String,
        isEnabled: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .styleText(
                        size: 16,
                        weight: .medium
                    )

                Text(description)
                    .styleText(
                        size: 13,
                        weight: .regular,
                        color: Color.S_2
                    )
            }

            Spacer()

            Toggle("", isOn: isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
               .stroke(Color.T_4, lineWidth: 1)
        )
    }
}
