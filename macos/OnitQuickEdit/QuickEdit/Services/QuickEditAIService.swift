//
//  QuickEditAIService.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import Foundation
import Defaults
import AppKit

@MainActor
class QuickEditAIService {

    // MARK: - Properties

    private let client = FetchingClient()
    private let streamingClient = StreamingClient()

    // MARK: - Generation

    /// Generates an AI response based on the instruction and context
    /// - Parameters:
    ///   - instruction: User's instruction (e.g., "Correct grammar", "Make it shorter")
    ///   - context: The QuickEdit request containing all context
    ///   - onChunk: Callback for streaming chunks of the response
    ///   - useRawInstruction: If true, use the instruction as-is without adding context
    /// - Returns: The complete generated response
    func generateResponse(
        instruction: String,
        context: QuickEditRequest,
        onChunk: @escaping (String) -> Void,
        useRawInstruction: Bool = false
    ) async throws -> String {
        // Build the instruction text with context (or use raw if specified)
        let instructionText: String
        if useRawInstruction {
            instructionText = instruction
        } else {
            instructionText = buildInstruction(
                instruction: instruction,
                selectedText: context.selectedText,
                surroundingText: context.textBefore,
                appName: context.applicationName
            )
        }

        // Determine which model to use based on QuickEdit settings
        let inferenceMode = Defaults[.quickEditMode]
        let (mode, modelName) = getAnalyticsInfo(for: inferenceMode)

        var fullResponse = ""
        let startTime = Date()
        let inputLength = instructionText.count

        // Get the bundle identifier of the frontmost app for memory filtering
        let appBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        do {
            try await executeGeneration(
                inferenceMode: inferenceMode,
                instructionText: instructionText,
                inputLength: inputLength,
                appBundleIdentifier: appBundleIdentifier,
                instruction: instruction,
                selectedText: context.selectedText,
                surroundingText: context.textBefore,
                fullResponse: &fullResponse,
                onChunk: onChunk
            )
        } catch {
            AnalyticsManager.QuickEdit.generationFailed(
                mode: mode,
                model: modelName,
                error: error.localizedDescription
            )
            throw error
        }

        let duration = Date().timeIntervalSince(startTime)
        AnalyticsManager.QuickEdit.generationCompleted(
            mode: mode,
            model: modelName,
            duration: duration,
            outputLength: fullResponse.count
        )

        return fullResponse
    }

    // MARK: - Analytics Helper

    private func getAnalyticsInfo(for inferenceMode: InferenceMode) -> (mode: String, modelName: String) {
        switch inferenceMode {
        case .remote:
            return ("remote", Defaults[.quickEditRemoteModel]?.displayName ?? "unknown")
        case .local:
            return ("local", Defaults[.quickEditLocalModel] ?? "unknown")
        }
    }

    // MARK: - Private Generation

    private func executeGeneration(
        inferenceMode: InferenceMode,
        instructionText: String,
        inputLength: Int,
        appBundleIdentifier: String?,
        instruction: String,
        selectedText: String?,
        surroundingText: String?,
        fullResponse: inout String,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let systemPrompt = await buildSystemPrompt(
            appBundleIdentifier: appBundleIdentifier,
            instruction: instruction,
            selectedText: selectedText,
            surroundingText: surroundingText
        )

        switch inferenceMode {
        case .remote:
            // Use remote model
            guard let model = Defaults[.quickEditRemoteModel] else {
                throw FetchingError.invalidRequest(message: String.localized("No remote model selected for QuickEdit", table: "QuickEdit"))
            }

            // Track generation start
            AnalyticsManager.QuickEdit.generationStarted(
                mode: "remote",
                model: model.displayName,
                inputLength: inputLength
            )

            let apiToken = TokenValidationManager.getTokenForModel(model)
            let useOnitChat = apiToken == nil || apiToken == ""

            if useOnitChat || shouldUseStream(model) {
                // Streaming mode
                let stream = try await streamingClient.chat(
                    systemMessage: systemPrompt,
                    instructions: [instructionText],
                    inputs: [nil],
                    files: [[]],
                    images: [[]],
                    autoContexts: [[:]],
                    webSearchContexts: [[]],
                    responses: [],
                    tools: [],
                    useOnitServer: useOnitChat,
                    model: model,
                    apiToken: apiToken,
                    includeSearch: nil,
                    featureType: "quick_edit"
                )

                for try await response in stream {
                    // Check for cancellation
                    try Task.checkCancellation()

                    if let content = response.content {
                        fullResponse += content
                        onChunk(content)
                    }
                }

                // If no response received, throw error
                if fullResponse.isEmpty {
                    throw FetchingError.noContent
                }

                // Clean response (strip markdown and remove artifacts)
                fullResponse = cleanResponse(fullResponse)
            } else {
                // Non-streaming mode
                let response = try await client.chat(
                    systemMessage: systemPrompt,
                    instructions: [instructionText],
                    inputs: [nil],
                    files: [[]],
                    images: [[]],
                    autoContexts: [[:]],
                    webSearchContexts: [[]],
                    responses: [],
                    model: model,
                    apiToken: apiToken,
                    tools: [],
                    includeSearch: nil
                )

                fullResponse = cleanResponse(response.content ?? "")
                onChunk(fullResponse)
            }

        case .local:
            // Use local model
            guard let localModel = Defaults[.quickEditLocalModel] else {
                throw FetchingError.invalidRequest(message: String.localized("No local model selected for QuickEdit", table: "QuickEdit"))
            }

            // Track generation start
            AnalyticsManager.QuickEdit.generationStarted(
                mode: "local",
                model: localModel,
                inputLength: inputLength
            )

            if Defaults[.streamResponse].local {
                // Streaming mode
                let stream = try await streamingClient.localChat(
                    systemMessage: systemPrompt,
                    instructions: [instructionText],
                    inputs: [nil],
                    files: [[]],
                    images: [[]],
                    autoContexts: [[:]],
                    webSearchContexts: [[]],
                    responses: [],
                    model: localModel,
                    tools: []
                )

                for try await response in stream {
                    // Check for cancellation
                    try Task.checkCancellation()

                    if let content = response.content {
                        fullResponse += content
                        onChunk(content)
                    }
                }

                // Clean response (strip markdown and remove artifacts)
                fullResponse = cleanResponse(fullResponse)
            } else {
                // Non-streaming mode
                let response = try await client.localChat(
                    systemMessage: systemPrompt,
                    instructions: [instructionText],
                    inputs: [nil],
                    files: [[]],
                    images: [[]],
                    autoContexts: [[:]],
                    webSearchContexts: [[]],
                    responses: [],
                    model: localModel,
                    tools: []
                )

                fullResponse = cleanResponse(response.content ?? "")
                onChunk(fullResponse)
            }
        }
    }

    // MARK: - Private Helpers

    /// Cleans AI response by removing markdown and common artifacts
    private func cleanResponse(_ response: String) -> String {
        var cleaned = response.stripMarkdown()
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }

    /// Builds the system prompt for QuickEdit with memories injection
    private func buildSystemPrompt(
        appBundleIdentifier: String?,
        instruction: String,
        selectedText: String?,
        surroundingText: String?
    ) async -> String {
        var prompt = """
        You are a helpful AI assistant for text editing and improvement.
        Your role is to help users improve, correct, or transform their text based on their instructions.

        Guidelines:
        - Be concise and direct
        - Follow the user's instruction precisely
        - If editing text, return only the edited version without explanations unless asked
        - Maintain the original tone and style unless instructed otherwise
        - If the instruction is unclear, make reasonable assumptions based on context
        - Never wrap your response in quotes or code blocks
        """

        return prompt
    }

    /// Builds the user instruction with context
    private func buildInstruction(
        instruction: String,
        selectedText: String?,
        surroundingText: String?,
        appName: String?
    ) -> String {
        var instructionText = instruction + "\n\n"

        // Add selected text if available (most important context)
        if let selected = selectedText, !selected.isEmpty {
            instructionText += "Text to process:\n\"\"\"\n\(selected)\n\"\"\"\n\n"
        }

        // Add surrounding context if available and auto-context is enabled
        if Defaults[.quickEditConfig].enableAutoContext,
           let surrounding = surroundingText, !surrounding.isEmpty {
            instructionText += "Additional context around the text:\n\"\"\"\n\(surrounding)\n\"\"\"\n\n"
        }

        // Add application context if available
        if let app = appName {
            instructionText += "Application the text came from: \(app)\n"
        }

        return instructionText
    }

    /// Determines if we should use streaming for the given model
    private func shouldUseStream(_ model: AIModel) -> Bool {
        let streamConfig = Defaults[.streamResponse]
        switch model.provider {
        case .openAI:
            return streamConfig.openAI
        case .anthropic:
            return streamConfig.anthropic
        case .deepSeek:
            return streamConfig.deepSeek
        case .googleAI:
            return streamConfig.googleAI
        case .perplexity:
            return streamConfig.perplexity
        case .xAI:
            return streamConfig.xAI
        case .cerebras:
            return streamConfig.cerebras
        case .custom:
            // Check custom provider streaming config
            if let customProviderName = model.customProviderName {
                return streamConfig.customProviders[customProviderName] ?? true
            }
            return true
        }
    }
}
