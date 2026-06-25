//
//  OnboardingQuickEditIntro.swift
//  Onit
//
//  Created by Loyd Kim on 1/20/26.
//

import Defaults
import SwiftUI

struct OnboardingQuickEditIntro: View {
    // MARK: - Body

    var body: some View {
        OnboardingPage(
            bodyConfig: .init(removeContentSpacer: true),
            footerConfig: .init(
                nextButtonText: String.localized("Next", table: "Onboarding"),
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
                /// Pushes the "Next" button to the trailing edge of the footer.
                Spacer()
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
}
