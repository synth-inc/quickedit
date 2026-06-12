//
//  TranslationManager.swift
//  Onit
//
//  Created by Loyd Kim on 12/30/25.
//

import Combine
import Defaults
import Foundation

@MainActor
final class TranslationManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = TranslationManager()
    
    // MARK: - Initialization
    
    private init() {
        if Defaults[.translationSourceLanguageCode] == nil {
            Defaults[.translationSourceLanguageCode] = sourceLanguageCode
        }
        if Defaults[.translationTargetLanguageCode] == nil {
            Defaults[.translationTargetLanguageCode] = targetLanguageCode
        }
        
        setupObservers()
        syncTranslationPromptsOnCustomPromptDBReady()
    }
    
    // MARK: - Published Properties
    
    @Published var sourceLanguageCode: String =
        Defaults[.translationSourceLanguageCode] ??
        Defaults[.translationBuildLanguageCode] ??
        LanguageHelpers.preferredLanguageCodes.first ??
        "en"
    
    @Published var targetLanguageCode: String =
        Defaults[.translationTargetLanguageCode] ??
        "en"
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Variables
    
    var targetLanguageCodeOptions: [String] {
        return [
            "en", "fr", "de", "es", "it", "ru", "pt", "ja", "ko", "zh"
        ].filter {
            $0 != self.sourceLanguageCode
        }
    }
    
    // MARK: - Public Functions
    
    func resetTargetLanguageCode() {
        self.targetLanguageCode = self.targetLanguageCodeOptions.first ?? "en"
    }
    
    func updateSourceLanguageCode() {
        Defaults[.translationSourceLanguageCode] = self.sourceLanguageCode
    }
    
    func updateTargetLanguageCode() {
        Defaults[.translationTargetLanguageCode] = self.targetLanguageCode
    }
    
    // MARK: - Private Functions
    
    private func syncTranslationPromptsOnCustomPromptDBReady() {
        /// If the `CustomPrompt` database is already ready, immediately sync translation prompts for the QuickEdit hint view.
        if CustomPromptManager.shared.isReady {
            Task {
                await syncTranslationPrompts()
            }
        }
        /// Otherwise, listen until the `CustomPrompt` database is ready and then sync.
        else {
            CustomPromptManager.shared.$isReady
                .filter { $0 == true }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.syncTranslationPrompts()
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func setupObservers() {
        Defaults.publisher(.translationSourceLanguageCode)
            .map(\.newValue)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncTranslationPrompts()
                }
            }
            .store(in: &self.cancellables)
        
        Defaults.publisher(.translationTargetLanguageCode)
            .map(\.newValue)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncTranslationPrompts()
                }
            }
            .store(in: &self.cancellables)
        
        Defaults.publisher(.quickEditConfig)
            .map(\.newValue.isEnabled)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                guard isEnabled else { return }
                Task { @MainActor in
                    await self?.syncTranslationPrompts()
                }
            }
            .store(in: &self.cancellables)
    }
    
    /// Syncs QuickEdit hint custom translation prompts based on current user-selected language codes for
    /// `Defaults[.translationSourceLanguageCode]` and `Defaults[.translationTargetLanguageCode]`
    private func syncTranslationPrompts() async {
        guard Defaults[.quickEditConfig].isEnabled && Defaults[.isTranslationBuild]
        else {
             return
        }
        
        await self.syncCustomTranslationPrompt(
            customTranslationPromptId: CustomPrompt.translationSourceID,
            languageCode: Defaults[.translationSourceLanguageCode]
        )
        
        await self.syncCustomTranslationPrompt(
            customTranslationPromptId: CustomPrompt.translationTargetID,
            languageCode: Defaults[.translationTargetLanguageCode]
        )
    }
    
    private func syncCustomTranslationPrompt(
        customTranslationPromptId: UUID,
        languageCode: String?
    ) async {
        let existingCustomTranslationPrompt = CustomPromptManager.shared.customPrompts.first {
            $0.id == customTranslationPromptId
        }
        
        /// If a language code (`Defaults[.translationSourceLanguageCode]` or `Defaults[.translationTargetLanguageCode]`) were selected by the user,
        ///     create or update a custom translation prompt for the QuickEdit hint view.
        if let languageCode = languageCode {
            /// Create or update the prompt
            let customTranslationPrompt = CustomPrompt.createCustomTranslationPrompt(
                customPromptId: customTranslationPromptId,
                languageCode: languageCode,
                order: existingCustomTranslationPrompt?.order ?? CustomPromptManager.shared.nextOrder()
            )
            
            /// If a custom translation prompt already exists, update it.
            if let existingPrompt = existingCustomTranslationPrompt {
                var updatedPrompt = customTranslationPrompt
                updatedPrompt.order = existingPrompt.order
                updatedPrompt.isEnabled = existingPrompt.isEnabled
                try? await CustomPromptManager.shared.updatePrompt(updatedPrompt)
            }
            /// Otherwise, create a new custom translation prompt
            else {
                try? await CustomPromptManager.shared.createPrompt(customTranslationPrompt)
            }
        }
        
        /// Otherwise, delete the custom translation prompt.
        else {
            let customTranslationPromptExists = existingCustomTranslationPrompt != nil
            
            if customTranslationPromptExists {
                try? await CustomPromptManager.shared.deletePrompt(
                    id: customTranslationPromptId
                )
            }
        }
    }
}
