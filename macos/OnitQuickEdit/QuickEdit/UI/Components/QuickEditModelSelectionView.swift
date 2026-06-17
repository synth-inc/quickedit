//
//  QuickEditModelSelectionView.swift
//  Onit
//
//  Created by Kévin Naudin on 11/27/2025.
//

import Defaults
import SwiftUI

struct QuickEditModelSelectionView: View {
    @Environment(\.appState) var appState
    @ObservedObject private var authManager = AuthManager.shared

    @Default(.quickEditMode) var quickEditMode
    @Default(.quickEditLocalModel) var quickEditLocalModel
    @Default(.quickEditRemoteModel) var quickEditRemoteModel
    @Default(.availableLocalModels) var availableLocalModels
    @Default(.visibleLocalModels) var visibleLocalModels

    private var open: Binding<Bool>
    private let availableModes: [InferenceMode]
    private let source: String

    init(open: Binding<Bool>, availableModes: [InferenceMode] = [.remote, .local], source: String = "QuickEdit") {
        self.open = open
        self.availableModes = availableModes
        self.source = source
    }

    @State var searchQuery: String = ""

    // MARK: - Filtered Models

    private var filteredRemoteModels: [AIModel] {
        let models: [AIModel]
        if searchQuery.isEmpty {
            models = appState.listedModels
        } else {
            models = appState.listedModels.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        // Sort Cerebras models first for QuickEdit
        return models.sorted { lhs, rhs in
            if lhs.provider == .cerebras && rhs.provider != .cerebras {
                return true
            } else if lhs.provider != .cerebras && rhs.provider == .cerebras {
                return false
            }
            return false
        }
    }

    private var filteredLocalModels: [String] {
        let visibleModels = availableLocalModels.filter { visibleLocalModels.contains($0) }

        if searchQuery.isEmpty {
            return visibleModels
        } else {
            return visibleModels.filter {
                $0.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    // MARK: - Selected Model Binding

    private var selectedModel: Binding<SelectedQuickEditModel?> {
        .init {
            switch quickEditMode {
            case .local:
                if let localModelName = quickEditLocalModel {
                    return .local(localModelName)
                }
            case .remote:
                if let aiModel = quickEditRemoteModel {
                    return .remote(aiModel)
                }
            }
            return nil
        } set: { newValue in
            guard let newValue else { return }
            switch newValue {
            case .remote(let aiModel):
                quickEditRemoteModel = aiModel
                quickEditMode = .remote
                AnalyticsManager.QuickEdit.ModelPicker.modelSelected(source: source, mode: "remote", model: aiModel.displayName)
            case .local(let localModelName):
                quickEditLocalModel = localModelName
                quickEditMode = .local
                AnalyticsManager.QuickEdit.ModelPicker.modelSelected(source: source, mode: "local", model: localModelName)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        MenuList(
            header: MenuHeader(title: String.localized("QuickEdit - AI Model", table: "QuickEdit")) {
                IconButton(
                    icon: .settingsCog,
                    tooltipPrompt: String.localized("Settings", table: "QuickEdit")
                ) {
                    AnalyticsManager.QuickEdit.ModelPicker.settingsPressed(source: source)
                    openQuickEditSettings()
                }
            },
            search: MenuList.Search(
                query: $searchQuery,
                placeholder: String.localized("Search models...", table: "QuickEdit")
            )
        ) {
            signInCTA

            if availableModes.contains(.remote) {
                remote
            }

            if availableModes.contains(.local) {
                local
            }
        }
        .onAppear {
            AnalyticsManager.QuickEdit.ModelPicker.opened(source: source)
        }
    }

    // MARK: - Sign In CTA

    @ViewBuilder
    private var signInCTA: some View {
        if !authManager.userLoggedIn && availableModes.contains(.remote) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String.localized("Sign in to access 30+ models from OpenAI, Anthropic and more!", table: "QuickEdit"))
                    .fixedSize(horizontal: false, vertical: true)
                    .styleText(
                        size: 13,
                        weight: .regular,
                        color: Color.S_1
                    )

                Button(String.localized("Sign In", table: "QuickEdit")) {
                    AuthHelpers.openAuth(from: .quickEdit)
                }
                .buttonStyle(SetUpButtonStyle(showArrow: true))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Remote Section

    private var remote: some View {
        MenuSection(
            title: String.localized("Remote", table: "QuickEdit"),
            showTopBorder: true,
            maxScrollHeight: !filteredRemoteModels.isEmpty ? setModelListHeight(
                listCount: CGFloat(filteredRemoteModels.count)
            ) : nil,
            contentRightPadding: 0,
            contentBottomPadding: 0,
            contentLeftPadding: 0
        ) {
            remoteModelsView
        }
    }

    private var remoteModelsView: some View {
        VStack(spacing: 0) {
            if filteredRemoteModels.isEmpty {
                if !authManager.userLoggedIn {
                    TextButton(
                        type: .clear,
                        text: String.localized("Sign up for access", table: "QuickEdit"),
                        iconConfig: .init(
                            leftIconName: "person"
                        ),
                        sizeConfig: .init(
                            horizontalPadding: 8,
                            height: 32
                        ),
                        alignmentConfig: .init(
                            horizontalAlignment: .leading
                        ),
                        statusConfig: .init(
                            fillContainer: true
                        )
                    ) {
                        AuthHelpers.openAuth(for: .signUp, from: .quickEdit)
                        open.wrappedValue = false
                    }
                }

                addModelCTAButton()
            } else {
                ForEach(filteredRemoteModels) { remoteModel in
                    TextButton(
                        type: .clear,
                        text: remoteModel.displayName,
                        iconConfig: .init(
                            leftIconImage: remoteModel.provider.icon
                        ),
                        sizeConfig: .init(
                            horizontalPadding: 8,
                            height: 32,
                        ),
                        alignmentConfig: .init(
                            horizontalAlignment: .leading
                        ),
                        statusConfig: .init(
                            selected: isSelectedRemoteModel(model: remoteModel),
                            fillContainer: true
                        )
                    ) {
                        selectedModel.wrappedValue = .remote(remoteModel)
                        open.wrappedValue = false
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Local Section

    private var local: some View {
        MenuSection(
            title: String.localized("Local", table: "QuickEdit"),
            showTopBorder: true,
            maxScrollHeight: !filteredLocalModels.isEmpty ? setModelListHeight(
                listCount: CGFloat(filteredLocalModels.count)
            ) : nil,
            contentRightPadding: 0,
            contentBottomPadding: 0,
            contentLeftPadding: 0
        ) {
            localModelsView
        }
    }

    private var localModelsView: some View {
        VStack(spacing: 0) {
            if availableLocalModels.isEmpty {
                addModelCTAButton(isLocal: true)
            } else {
                ForEach(filteredLocalModels, id: \.self) { localModelName in
                    TextButton(
                        type: .clear,
                        text: localModelName,
                        iconConfig: .init(
                            leftIconImage: localModelName.lowercased().contains("llama") ? .logoOllama : .logoProviderUnknown
                        ),
                        sizeConfig: .init(
                            horizontalPadding: 8,
                            height: 32
                        ),
                        alignmentConfig: .init(
                            horizontalAlignment: .leading
                        ),
                        statusConfig: .init(
                            selected: isSelectedLocalModel(modelName: localModelName),
                            fillContainer: true
                        )
                    ) {
                        selectedModel.wrappedValue = .local(localModelName)
                        open.wrappedValue = false
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Helper Views

    private func addModelCTAButton(isLocal: Bool = false) -> some View {
        TextButton(
            type: .clear,
            text: String.localized("Add manually", table: "QuickEdit"),
            iconConfig: .init(
                leftIconName: "plus"
            ),
            sizeConfig: .init(
                horizontalPadding: 8,
                height: 32
            ),
            alignmentConfig: .init(
                horizontalAlignment: .leading
            ),
            statusConfig: .init(
                fillContainer: true
            )
        ) {
            if isLocal {
                AnalyticsManager.QuickEdit.ModelPicker.localSetupPressed(source: source)
            }

            AppWindowManager.shared.showWindow(settingsPage: .general)
            open.wrappedValue = false
        }
    }
}

// MARK: - Private Functions

extension QuickEditModelSelectionView {

    private func setModelListHeight(listCount: CGFloat) -> CGFloat {
        let buttonHeight: CGFloat = 32

        let maxShownButtonCount: CGFloat = 6
        let nextButtonPeekHeight: CGFloat = 20
        let listMaxHeight: CGFloat = (maxShownButtonCount * buttonHeight) + nextButtonPeekHeight

        let listBottomPaddingBuffer: CGFloat = 8
        let listHeight: CGFloat = listCount * buttonHeight + listBottomPaddingBuffer

        if listHeight < listMaxHeight {
            return listHeight
        } else {
            return listMaxHeight
        }
    }

    private func openQuickEditSettings() {
        AppWindowManager.shared.showWindow(settingsPage: .quickEditPrompts)
        open.wrappedValue = false
    }

    private func isSelectedRemoteModel(model: AIModel) -> Bool {
        if let currentModel = selectedModel.wrappedValue,
           case let .remote(selectedModel) = currentModel {
            return model.id == selectedModel.id
        }
        return false
    }

    private func isSelectedLocalModel(modelName: String) -> Bool {
        if let currentModel = selectedModel.wrappedValue,
           case let .local(selectedName) = currentModel {
            return modelName == selectedName
        }
        return false
    }
}

// MARK: - SelectedQuickEditModel

enum SelectedQuickEditModel: Equatable {
    case remote(AIModel)
    case local(String)
}

// MARK: - ModelProvider Extension

extension AIModel.ModelProvider {
    var icon: ImageResource {
        switch self {
        case .openAI:
            return .logoOpenai
        case .anthropic:
            return .logoAnthropic
        case .xAI:
            return .logoXai
        case .googleAI:
            return .logoGoogleai
        case .deepSeek:
            return .logoDeepseek
        case .perplexity:
            return .logoPerplexity
        case .cerebras:
            return .logoCerebras
        case .custom:
            return .logoProviderUnknown
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var open = true
    QuickEditModelSelectionView(
        open: $open,
        availableModes: [.remote, .local]
    )
}
