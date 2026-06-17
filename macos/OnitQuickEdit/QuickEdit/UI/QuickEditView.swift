//
//  QuickEditView.swift
//  Onit
//
//  Created by Loyd Kim on 11/21/25.
//

import SwiftUI

struct QuickEditView: View {
    // MARK: - Properties

    @ObservedObject var state: QuickEditState
    @ObservedObject private var localization = LocalizationManager.shared
    
    // MARK: - States
    
    @State private var shouldAnimateScaleTransition = false
    
    // MARK: - Private Variables
    
    private var scaleAnimationAnchorAlignment: UnitPoint {
        return state.isDisplayedBelowHighlightedText ? .topLeading : .bottomLeading
    }
    
    private var chatAnimationTransition: AnyTransition {
        .asymmetric(
            insertion:
                .move(edge: .bottom)
                .combined(with: .scale(scale: 0.96, anchor: self.scaleAnimationAnchorAlignment))
                .combined(with: .opacity),
            removal:
                .move(edge: .bottom)
                .combined(with: .scale(scale: 0.98, anchor: self.scaleAnimationAnchorAlignment))
                .combined(with: .opacity)
        )
    }

    // MARK: - Body

    var body: some View {
        contentView
            .frame(
                minWidth: QuickEditConstants.maxWindowWidth,
                maxWidth: QuickEditConstants.maxWindowWidth,
                maxHeight: QuickEditConstants.maxWindowHeight,
                alignment: state.isDisplayedBelowHighlightedText ? .topLeading : .bottomLeading
            )
            .scaleEffect(
                self.shouldAnimateScaleTransition ? 1.0 : 0.05,
                anchor: self.scaleAnimationAnchorAlignment
            )
            .opacity(self.shouldAnimateScaleTransition ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.9),
                value: self.shouldAnimateScaleTransition
            )
            .onAppear {
                self.shouldAnimateScaleTransition = true
                
                Task {
                    await QuickEditConversationHistoryManager.shared.loadConversationHistory()
                }
            }
            .onChange(of: self.state.isVisible) { _, isVisible in
                self.shouldAnimateScaleTransition = isVisible
            }
            .onChange(of: state.generationState) { previousGenerationState, currentGenerationState in
                let wasGenerating = previousGenerationState == .generating || previousGenerationState == .streaming
                let generationDone = currentGenerationState == .done

                let generationCompletedSuccessfully = wasGenerating && generationDone && !state.aiResponse.isEmpty

                if generationCompletedSuccessfully {
                    Task {
                        let globalSnapshots = QuickEditSelectionService.shared.globalHistory

                        let globalSnapshotsJSON: String? = {
                            guard !globalSnapshots.isEmpty,
                                  let data = try? JSONEncoder().encode(globalSnapshots)
                            else {
                                return nil
                            }

                            return String(data: data, encoding: .utf8)
                        }()

                        try await QuickEditConversationHistoryManager.shared.createOrUpdateConversation(
                            conversationId: QuickEditConversationHistoryManager.shared.currentConversationId,
                            mode: state.mode ?? .prompt,
                            appName: state.currentAppName,
                            selectedText: state.selectedText ?? "",
                            userInstruction: state.mode == .improve ? nil : state.userInstruction,
                            aiResponse: state.aiResponse,
                            globalSnapshotsJSON: globalSnapshotsJSON
                        )
                    }
                }
            }
            .id(localization.currentLanguage)
    }

    // MARK: - Child Components

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickEditHeader(state: state)
                .padding(.bottom, 10)

            // Order is always: Selected text → History → TextField
            chatSection
            QuickEditPromptToolbar(state: state)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: QuickEditConstants.maxWindowWidth, alignment: .leading)
        .background(Color.S_10.opacity(0.4))
        .background(Backgrounds.BrushedGlass())
        .addBorder(
            cornerRadius: 14,
            stroke: Color.T_7
        )
        .onDisappear {
            state.reset()
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.9),
            value: state.shouldShowChat
        )
    }

    @ViewBuilder
    private var chatSection: some View {
        if state.shouldShowChat {
            VStack(alignment: .leading, spacing: 0) {
                QuickEditChat(state: state)
                    .padding(.bottom, 8)

                QuickEditChatToolbar(
                    state: state,
                    shouldShow: !state.isPaywallActive && !state.isAuthWallActive
                )
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 10)
            .transition(self.chatAnimationTransition)

            QuickEditDiffNotification(state: state)
        }
    }
}
