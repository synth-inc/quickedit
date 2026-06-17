//
//  OnboardingQuickEditDemo.swift
//  Onit
//
//  Created by Kévin Naudin on 28/11/2025.
//

import Defaults
import SwiftUI

struct OnboardingQuickEditDemo: View {
    // MARK: - Constants

    private let originalText = """
QuickEdit is this thing that like pops up when you need it while working on texts like messages and stuff. is it like chatgpt?? no not really bcz is waaay more light and fast and it doesn't require you to like switch tabs and copypaste etc which rly disrupts your flow. anyways we think you'll love it :))
"""

    // MARK: - Defaults

    @Default(.currentOnboardingStep) var currentStep

    // MARK: - States

    /// Current demo step progress:
    /// 1 = Initial state (no steps completed)
    /// 2 = Step 1 completed (text selected)
    /// 3 = Step 2 completed (clicked Improve/Edit)
    /// 4 = Step 3 completed (clicked Insert)
    @State private var demoStep: Int = 1

    /// The text displayed in the textbox
    @State private var displayedText: String = ""

    /// Current selection info
    @State private var currentSelection: DemoTextSelection?

    /// Whether QuickEdit hint is currently shown
    @State private var isHintShown: Bool = false

    // MARK: - Body

    var body: some View {
        OnboardingPage(
            headerConfig: .init(paddingTop: 43),
            footerConfig: .init(
                nextButtonDisabled: Binding(
                    get: { demoStep < 4 },
                    set: { _ in }
                )
            ),
            bodyContent: {
                VStack(spacing: 0) {
                    DemoStepIndicator(currentStep: demoStep)
                        .padding(.top, 16)

                    DemoTextBox(
                        text: $displayedText,
                        onSelectionChanged: handleSelectionChanged
                    )
                    .padding(.top, 32)
                    
                    if demoStep == 4 {
                        Spacer()
                        
                        Text(String.localized(
                            "Try the 'Edit' (􀆔K) option and enter a prompt like 'inspirational' or 'email'", 
                            table: "Onboarding"
                        ))
                        .styleText(
                            size: 13
                        )
                        
                        Spacer()
                    }
                }
            },
            footerContent: {
                Spacer()

                if demoStep < 4 {
                    Button {
                        skipDemo()
                    } label: {
                        Text(String.localized("Skip Demo", table: "Onboarding"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.T_2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 16)
                }
            }
        )
        .onAppear {
            displayedText = originalText
            AnalyticsManager.QuickEdit.onboardingDemoShown()
        }
        .onDisappear {
            QuickEditManager.shared.hideDemoHint()
        }
        .onChange(of: demoStep) { _, newStep in
            if newStep == 4 {
                AnalyticsManager.QuickEdit.onboardingDemoCompleted()
            }
        }
    }

    // MARK: - Private Functions: Navigation

    private func skipDemo() {
        AnalyticsManager.QuickEdit.onboardingDemoSkipped()
        QuickEditManager.shared.hideDemoHint()
        if let next = currentStep?.nextStep() {
            currentStep = next
        }
    }

    // MARK: - Private Functions: Demo Logic

    private func handleSelectionChanged(_ selection: DemoTextSelection?) {
        DispatchQueue.main.async {
            currentSelection = selection

            if let selection = selection {
                // User selected text - show QuickEdit hint
                if !isHintShown {
                    showQuickEditHint(selection: selection)
                }
            } else {
                // Selection cleared - hide QuickEdit
                if isHintShown {
                    QuickEditManager.shared.hideDemoHint()
                    isHintShown = false
                }

                // Reset step if demo not completed
                if demoStep < 4 {
                    demoStep = 1
                }
            }
        }
    }

    private func showQuickEditHint(selection: DemoTextSelection) {
        isHintShown = true

        if demoStep < 2 {
            demoStep = 2
        }

        QuickEditManager.shared.showDemoHint(
            selectionBounds: selection.screenBounds,
            selectedText: selection.text,
            onAction: { mode in
                demoStep = 3
            },
            onInsert: { generatedText in
                replaceSelectedText(with: generatedText)
                demoStep = 4
                isHintShown = false
            }
        )
    }

    private func replaceSelectedText(with newText: String) {
        guard let selection = currentSelection else { return }

        let nsString = displayedText as NSString
        let range = selection.range

        // Ensure range is valid
        guard range.location != NSNotFound,
              range.location + range.length <= nsString.length else {
            return
        }

        // Replace the selected text with the generated text
        displayedText = nsString.replacingCharacters(in: range, with: newText)
        currentSelection = nil
    }
}
