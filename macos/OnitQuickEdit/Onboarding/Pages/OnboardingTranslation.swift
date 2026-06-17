//
//  OnboardingTranslation.swift
//  Onit
//
//  Created by Loyd Kim on 12/29/25.
//

import Defaults
import SwiftUI

struct OnboardingTranslation: View {
    // MARK: - Defaults

    @Default(.currentOnboardingStep) private var currentStep
    
    // MARK: - States
    
    @ObservedObject private var translationManager = TranslationManager.shared
    
    // MARK: - Body
    
    var body: some View {
        OnboardingPage(
            bodyContent: {
                VStack(alignment: .leading, spacing: 20) {
                    sourceLanguageSection
                    DividerHorizontal(foregroundColor: Color.T_9)
                    targetLanguageSection
                    DividerHorizontal(foregroundColor: Color.T_9)
                }
                .padding(.top, 62)
                .frame(width: 509)
            },
            footerContent: {
                Spacer()
                skipButton
            },
            footerCaption: {
                HStack(alignment: .center, spacing: 4) {
                    Image(.lockFilled)
                        .addIconStyles(
                            foregroundColor: Color.S_1,
                            iconSize: 13
                        )

                    Text(String.localized("Your data is stored locally on your Mac", table: "Onboarding"))
                        .styleText(
                            size: 12,
                            weight: .regular,
                            color: Color.S_1
                        )
                }
            }
        )
        .onChange(of: self.translationManager.sourceLanguageCode) { _, sourceLanguageCode in
            let shouldResetTargetLanguageCode = self.translationManager.targetLanguageCode == sourceLanguageCode
            
            if shouldResetTargetLanguageCode {
                self.translationManager.resetTargetLanguageCode()
                self.translationManager.updateTargetLanguageCode()
            }
        }
    }
    
    // MARK: - Child Components
    
    private var skipButton: some View {
        Button {
            skipStep()
        } label: {
            Text(String.localized("Skip", table: "Onboarding"))
                .styleText(
                    fontFamily: .inter,
                    weight: .regular
                )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 26)
    }
    
    private struct Dropdown: View {
        @Binding var selectedLanguageCodeOption: String
        var languageCodeOptions: [String]
        var onSelect: (String) -> Void
        
        @State private var showOptions: Bool = false
        
        var body: some View {
            TextButton(
                colorConfig: .init(
                    background: Color.clear,
                    border: Color.T_3
                ),
                sizeConfig: .init(
                    horizontalPadding: 12,
                    height: 37
                ),
                statusConfig: .init(
                    borderDotted: true
                )
            ) {
                HStack(alignment: .center, spacing: 0) {
                    Text(LanguageHelpers.getLocalizedLanguageCodeDisplayName(for: selectedLanguageCodeOption))
                        .styleText(
                            size: 13,
                            weight: .regular,
                            color: Color.S_0
                        )

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.S_0)
                        .rotationEffect(.degrees(showOptions ? 180 : 0))
                        .addAnimation(dependency: showOptions)
                }
            } action: {
                showOptions.toggle()
            }
            .addBorder(
                cornerRadius: 8,
                stroke: Color.T_9
            )
            .popover(isPresented: self.$showOptions) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.languageCodeOptions, id: \.self) { option in
                        Button {
                            self.onSelect(option)
                            self.showOptions = false
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Text(LanguageHelpers.getLocalizedLanguageCodeDisplayName(for: option))
                                    .styleText(
                                        size: 13,
                                        weight: .regular
                                    )
                                
                                if option == self.selectedLanguageCodeOption {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.S_0)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func dropdownSection(
        icon: ImageResource,
        title: String,
        caption: String,
        selection: Binding<String>,
        languageCodeOptions: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(icon)
                    .addIconStyles(
                        foregroundColor: Color.T_2,
                        iconSize: 24
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .styleText(
                            size: 15,
                            weight: .regular
                        )
                    
                    Text(caption)
                        .styleText(
                            size: 14,
                            weight: .regular,
                            color: Color.T_2
                        )
                }
            }
            
            Spacer()
            
            Dropdown(
                selectedLanguageCodeOption: selection,
                languageCodeOptions: languageCodeOptions,
                onSelect: onSelect
            )
        }
    }
    
    private var sourceLanguageSection: some View {
        dropdownSection(
            icon: .accessibility,
            title: String.localized("Your language", table: "Onboarding"),
            caption: String.localized("Your preferred language.", table: "Onboarding"),
            selection: self.$translationManager.sourceLanguageCode,
            languageCodeOptions: LanguageHelpers.sourceLanguageCodes
        ) { selectedLanguageCode in
            self.translationManager.sourceLanguageCode = selectedLanguageCode
            self.translationManager.updateSourceLanguageCode()
        }
    }

    private var targetLanguageSection: some View {
        dropdownSection(
            icon: .screenshots,
            title: String.localized("Target Language", table: "Onboarding"),
            caption: String.localized("The language your recipients expect.", table: "Onboarding"),
            selection: self.$translationManager.targetLanguageCode,
            languageCodeOptions: self.translationManager.targetLanguageCodeOptions
        ) { selectedLanguageCode in
            self.translationManager.targetLanguageCode = selectedLanguageCode
            self.translationManager.updateTargetLanguageCode()
        }
    }
    
    // MARK: - Private Functions
    
    private func skipStep() {
        guard let nextStep = currentStep?.nextStep() else { return }
        currentStep = nextStep
    }
}
