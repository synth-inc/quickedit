//
//  SettingsQuickEditDev.swift
//  Onit
//
//  Created by Kévin Naudin on 12/04/2025.
//

import Defaults
import SwiftUI

struct SettingsQuickEditDev: View {
    // MARK: - Defaults

    @Default(.quickEditConfig) private var config
    @Default(.quickEditMode) private var quickEditMode
    @Default(.quickEditLocalModel) private var quickEditLocalModel
    @Default(.quickEditRemoteModel) private var quickEditRemoteModel
    @Default(.quickEditSmartPositioning) private var smartPositioning
    @Default(.quickEditAlwaysShowDiffViewOnImprove) private var alwaysShowDiffViewOnImprove

    // MARK: - States

    @State private var modelPickerOpen = false

    // MARK: - Body

    var body: some View {
        displaySettingsSection
        modelSettingsSection

        #if DEBUG || ONIT_BETA
        experimentalTriggersSection
        trainingDataSection
        #endif
    }

    // MARK: - Child Components: Display Settings Section

    private var displaySettingsSection: some View {
        SettingsPageSection(title: .init(text: String.localized("Display Settings", table: "QuickEdit"))) {
            diffViewSettings
            
            DividerHorizontal()

            SettingsPageSubsection(
                header: .init(
                    title: String.localized("Enable auto context", table: "QuickEdit"),
                    subtitle: String.localized("Include surrounding text from keyboard for better context.", table: "QuickEdit")
                ),
                isOn: self.$config.enableAutoContext
            )
            
            DividerHorizontal()

            SettingsPageSubsection(
                header: .init(
                    title: String.localized("Smart hint positioning", table: "QuickEdit"),
                    subtitle: String.localized("Position hint in empty screen areas to avoid covering content. Uses GPU-accelerated image analysis to find empty areas on screen.", table: "QuickEdit")
                ),
                isOn: self.$smartPositioning
            )
        }
    }
    
    private var diffViewSettings: some View {
        SettingsPageSubsection(
            header: .init(
                title: String.localized("Always Show Diff View on Improve", table: "QuickEdit"),
                subtitle: String.localized("Automatically turn on Diff View on \"Improve\" results.", table: "QuickEdit")
            ),
            isOn: $alwaysShowDiffViewOnImprove
        )
    }
    
    // MARK: - Child Components: Model Settings Section

    private var modelSettingsSection: some View {
        SettingsPageSection(title: .init(text: String.localized("Model Settings", table: "QuickEdit"))) {
            SettingsPageSubsection(
                header: .init(
                    title: String.localized("Model", table: "QuickEdit"),
                    subtitle: currentModelDescription
                )
            ) {
                Button(action: {
                    modelPickerOpen = true
                }) {
                    HStack(spacing: 4) {
                        Text(currentModelDisplayName)
                            .styleText(size: 13)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.S_2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.T_8)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $modelPickerOpen) {
                    QuickEditModelSelectionView(
                        open: $modelPickerOpen,
                        availableModes: [.remote, .local],
                        source: "Settings"
                    )
                }
            }
        }
    }
    
    // MARK: - Child Components: Experimental Triggers Section

    #if DEBUG || ONIT_BETA
    private var experimentalTriggersSection: some View {
        SettingsPageSection(title: .init(text: String.localized("Experimental Triggers", table: "QuickEdit"))) {
            SettingsPageSubsection(
                header: .init(
                    title: String.localized("Non-accessibility trigger", table: "QuickEdit"),
                    subtitle: String.localized("Detect text selection using image diff instead of accessibility APIs. When enabled, replaces the standard trigger service.", table: "QuickEdit")
                ),
                isOn: self.$config.enableNonAccessibilityTrigger
            )
        }
    }
    
    // MARK: - Child Components: Training Data Section

    private var trainingDataSection: some View {
        SettingsPageSection(title: .init(text: String.localized("Training Data", table: "QuickEdit"))) {
            SettingsPageSubsection(
                vertical: .init(spacing: 12),
                header: .init(
                    title: String.localized("Collect and review training data for model to automatically detect text bounds from screenshots.", table: "QuickEdit")
                )
            ) {
                HighlightedTextBoundTrainingDataReviewView()
            }
        }
    }
    #endif

    // MARK: - Computed Properties

    private var currentModelDisplayName: String {
        switch quickEditMode {
        case .remote:
            return quickEditRemoteModel?.displayName ?? String.localized("Select Remote Model", table: "QuickEdit")
        case .local:
            return quickEditLocalModel ?? String.localized("Select Local Model", table: "QuickEdit")
        }
    }

    private var currentModelDescription: String {
        switch quickEditMode {
        case .remote:
            if let model = quickEditRemoteModel {
                let hasToken = TokenValidationManager.getTokenForModel(model) != nil
                return hasToken ? String.localized("Using your API token", table: "QuickEdit") : String.localized("Using remote AI model via QuickEdit servers", table: "QuickEdit")
            }
            return String.localized("Select a remote model", table: "QuickEdit")
        case .local:
            return String.localized("Using local model via Ollama", table: "QuickEdit")
        }
    }
}
