//
//  OnboardingQuickEditIntro.swift
//  Onit
//
//  Created by Loyd Kim on 1/20/26.
//

import Defaults
import SwiftUI

struct OnboardingQuickEditIntro: View {
    // MARK: - Defaults

    @Default(.currentOnboardingStep) var currentStep
    @Default(.quickEditConfig) var quickEditConfig

    // MARK: - States

    @State private var isHoveredSkipButton: Bool = false
    @State private var isPressedSkipButton: Bool = false

    // MARK: - Body

    var body: some View {
        OnboardingPage(
            bodyConfig: .init(removeContentSpacer: true),
            footerConfig: .init(
                nextButtonText: String.localized("Set Up QuickEdit", table: "Onboarding"),
                nextButtonRightIconName: "arrow.right"
            ),
            headerContent: {
                OnboardingTitlePill(
                    textConfig: .init(text: String.localized("QuickEdit", table: "Onboarding")),
                    leftIconConfig: .init(systemName: "wand.and.stars")
                )
            },
            bodyContent: {
                Group {
                    demoVideo
                }
                .padding(.top, 25)
                .padding(.bottom, 27)
            },
            footerContent: {
                Spacer()
                skipButton
            }
        )
        .onAppear {
            AnalyticsManager.QuickEdit.onboardingIntroShown()
        }
    }

    // MARK: - Child Components
    
    private var demoVideo: some View {
        VideoPlayerView(
            videoAssetName: "onboarding-quickedit-demo"
        )
        .frame(width: 434)
        .addBorder(
            cornerRadius: 18,
            stroke: Color.S_0.opacity(0.24)
        )
        
    }

    private var skipButton: some View {
        Button {
            AnalyticsManager.QuickEdit.onboardingIntroSkipped()
            currentStep = .permissions
        } label: {
            Text(String.localized("I'll do it later", table: "Onboarding"))
                .styleText(
                    fontFamily: .inter,
                    weight: .regular
                )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 26)
    }
}
