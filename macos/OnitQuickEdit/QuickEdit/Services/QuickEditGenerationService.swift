//
//  QuickEditGenerationService.swift
//  Onit
//
//  Created by Kévin Naudin on 12/10/2025.
//

import Defaults
import Foundation

/// Centralized service for all QuickEdit AI generation operations.
/// Handles Task tracking, cancellation, and state management.
@MainActor
class QuickEditGenerationService {

    // MARK: - Singleton

    static let shared = QuickEditGenerationService()

    // MARK: - Dependencies

    private let aiService = QuickEditAIService()
    private let selectionService = QuickEditSelectionService.shared
    private let diffService = QuickEditDiffService.shared

    // MARK: - State

    private var currentTask: Task<Void, Never>?

    /// Generation ID to track stale requests. Incremented on each new generation.
    /// Used to ignore results from cancelled/outdated generations.
    private var currentGenerationId: UInt64 = 0

    private init() {}

    // MARK: - Public API

    /// Cancels the current generation task if any
    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        // Increment generation ID so any in-flight results are ignored
        currentGenerationId &+= 1
    }

    /// Performs a standard generation (Improve or Edit mode)d
    /// - Parameters:
    ///   - instruction: The user instruction
    ///   - context: The QuickEdit request context
    ///   - state: The QuickEdit state to update
    ///   - onChunk: Callback for streaming chunks
    func performStandardGeneration(
        instruction: String,
        context: QuickEditRequest,
        state: QuickEditState,
        onChunk: @escaping (String) -> Void
    ) {
        cancelGeneration()

        // Capture generation ID to detect stale results
        let generationId = currentGenerationId

        currentTask = Task {
            state.generationState = .generating

            do {
                let response = try await aiService.generateResponse(
                    instruction: instruction,
                    context: context,
                    onChunk: { [weak state] chunk in
                        guard let state = state else { return }
                        Task { @MainActor in
                            if state.generationState == .generating {
                                state.generationState = .streaming
                            }
                            onChunk(chunk)
                        }
                    }
                )

                // Ignore results if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else { return }

                try Task.checkCancellation()

                state.aiResponse = response
                state.generationState = .done
                state.isGenerating = false

                // Update selection service and create snapshot for history
                selectionService.updateText(response)
                selectionService.createGlobalSnapshotPublic(
                    instruction: self.sanitizeImproveInstruction(instruction)
                )

                // Auto-enable diff view on Improve if setting is enabled
                if state.mode == .improve && Defaults[.quickEditAlwaysShowDiffViewOnImprove] {
                    if let originalText = state.selectedText {
                        diffService.computeDiff(original: originalText, response: response)
                        state.isDiffViewEnabled = true
                    }
                }

            } catch is CancellationError {
                // Ignore cancellation if this generation was superseded
                guard generationId == self.currentGenerationId else { return }
                state.generationState = .done
                state.isGenerating = false
            } catch {
                // Ignore errors if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else { return }

                state.error = error
                state.generationState = .done
                state.isGenerating = false
            }
        }
    }

    /// Performs a global retry with frozen text preserved
    /// - Parameters:
    ///   - instruction: The original user instruction
    ///   - context: The QuickEdit request context
    ///   - state: The QuickEdit state to update
    ///   - onChunk: Callback for streaming chunks
    func performGlobalRetry(
        instruction: String,
        context: QuickEditRequest,
        state: QuickEditState,
        onChunk: @escaping (String) -> Void
    ) {
        cancelGeneration()

        // Capture generation ID to detect stale results
        let generationId = currentGenerationId

        selectionService.startGlobalRegeneration()
        let frozenTexts = selectionService.getFrozenTexts()

        currentTask = Task {
            state.generationState = .generating

            do {
                let fullInstruction = QuickEditPromptBuilder.buildGlobalRetryInstruction(
                    originalInstruction: instruction,
                    fullText: selectionService.fullText,
                    frozenPortions: frozenTexts
                )

                let response = try await aiService.generateResponse(
                    instruction: fullInstruction,
                    context: context,
                    onChunk: { [weak state] chunk in
                        guard let state = state else { return }
                        Task { @MainActor in
                            if state.generationState == .generating {
                                state.generationState = .streaming
                            }
                            onChunk(chunk)
                        }
                    },
                    useRawInstruction: true
                )

                // Ignore results if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endGlobalRegeneration()
                    return
                }

                try Task.checkCancellation()

                selectionService.updateAfterGlobalRegeneration(newText: response, previousFrozenTexts: frozenTexts, instruction: instruction)
                state.aiResponse = response
                state.generationState = .done
                state.isGenerating = false
                selectionService.endGlobalRegeneration()

            } catch is CancellationError {
                // Ignore cancellation if this generation was superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endGlobalRegeneration()
                    return
                }
                state.generationState = .done
                state.isGenerating = false
                selectionService.endGlobalRegeneration()
            } catch {
                // Ignore errors if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endGlobalRegeneration()
                    return
                }

                state.error = error
                state.generationState = .done
                state.isGenerating = false
                selectionService.endGlobalRegeneration()
            }
        }
    }

    /// Performs a segment retry (regenerate selected portion)
    /// - Parameters:
    ///   - range: The range of text to retry
    ///   - context: The QuickEdit request context
    ///   - state: The QuickEdit state to update
    ///   - onComplete: Callback with the updated segment (if successful)
    func performSegmentRetry(
        range: NSRange,
        context: QuickEditRequest,
        state: QuickEditState,
        onComplete: @escaping (TextSegment?) -> Void
    ) {
        cancelGeneration()

        // Capture generation ID to detect stale results
        let generationId = currentGenerationId

        // Get context for the range (selection may have been cleared)
        guard let selectionContext = selectionService.getContextForRange(range) else {
            onComplete(nil)
            return
        }

        selectionService.startRegeneration(for: range)
        state.generationState = .generating

        currentTask = Task {
            do {
                let instruction = QuickEditPromptBuilder.buildRetryInstruction(
                    textBefore: selectionContext.before,
                    selectedText: selectionContext.selected,
                    textAfter: selectionContext.after
                )

                let result = try await aiService.generateResponse(
                    instruction: instruction,
                    context: context,
                    onChunk: { [weak state] _ in
                        guard let state = state else { return }
                        Task { @MainActor in
                            if state.generationState == .generating {
                                state.generationState = .streaming
                            }
                        }
                    },
                    useRawInstruction: true
                )

                // Ignore results if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }

                try Task.checkCancellation()

                // Post-process to preserve whitespace and punctuation
                let processedResult = QuickEditPromptBuilder.preserveWhitespaceAndPunctuation(
                    original: selectionContext.selected,
                    generated: result
                )

                let segmentInstruction = buildDescriptiveSegmentInstruction(
                    previousInstruction: selectionService.currentSnapshot?.instruction,
                    action: "Retry",
                    selectedText: selectionContext.selected
                )
                
                let updatedSegment = selectionService.updateSegmentWithNewVersion(
                    range: range,
                    newText: processedResult,
                    source: .retry,
                    instruction: segmentInstruction
                )

                state.aiResponse = selectionService.fullText
                selectionService.endRegeneration()
                state.generationState = .done

                state.headerConfig = .fromInstruction(segmentInstruction)

                onComplete(updatedSegment)

            } catch is CancellationError {
                // Ignore cancellation if this generation was superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }
                selectionService.endRegeneration()
                state.generationState = .done
                onComplete(nil)
            } catch {
                // Ignore errors if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }

                selectionService.endRegeneration()
                state.generationState = .done
                onComplete(nil)
            }
        }
    }

    /// Performs a segment AI edit with custom instruction
    /// - Parameters:
    ///   - range: The range of text to edit
    ///   - instruction: The user's edit instruction
    ///   - context: The QuickEdit request context
    ///   - state: The QuickEdit state to update
    ///   - onComplete: Callback with the updated segment (if successful)
    func performSegmentAIEdit(
        range: NSRange,
        instruction: String,
        context: QuickEditRequest,
        state: QuickEditState,
        onComplete: @escaping (TextSegment?) -> Void
    ) {
        cancelGeneration()

        // Capture generation ID to detect stale results
        let generationId = currentGenerationId

        // Get context for the range (selection may have been cleared)
        guard let selectionContext = selectionService.getContextForRange(range) else {
            onComplete(nil)
            return
        }

        selectionService.startRegeneration(for: range)
        state.generationState = .generating

        currentTask = Task {
            do {
                let fullInstruction = QuickEditPromptBuilder.buildAIEditInstruction(
                    textBefore: selectionContext.before,
                    selectedText: selectionContext.selected,
                    textAfter: selectionContext.after,
                    userInstruction: instruction
                )

                let result = try await aiService.generateResponse(
                    instruction: fullInstruction,
                    context: context,
                    onChunk: { [weak state] _ in
                        guard let state = state else { return }
                        Task { @MainActor in
                            if state.generationState == .generating {
                                state.generationState = .streaming
                            }
                        }
                    },
                    useRawInstruction: true
                )

                // Ignore results if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }

                try Task.checkCancellation()

                // Post-process to preserve whitespace and punctuation
                let processedResult = QuickEditPromptBuilder.preserveWhitespaceAndPunctuation(
                    original: selectionContext.selected,
                    generated: result
                )

                let segmentInstruction = buildDescriptiveSegmentInstruction(
                    previousInstruction: selectionService.currentSnapshot?.instruction,
                    action: instruction,
                    selectedText: selectionContext.selected
                )
                
                let updatedSegment = selectionService.updateSegmentWithNewVersion(
                    range: range,
                    newText: processedResult,
                    source: .aiEdit(instruction: instruction),
                    instruction: segmentInstruction
                )

                state.aiResponse = selectionService.fullText
                selectionService.endRegeneration()
                state.generationState = .done

                state.headerConfig = .fromInstruction(segmentInstruction)

                onComplete(updatedSegment)

            } catch is CancellationError {
                // Ignore cancellation if this generation was superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }
                selectionService.endRegeneration()
                state.generationState = .done
                onComplete(nil)
            } catch {
                // Ignore errors if this generation was cancelled/superseded
                guard generationId == self.currentGenerationId else {
                    selectionService.endRegeneration()
                    onComplete(nil)
                    return
                }

                selectionService.endRegeneration()
                state.generationState = .done
                onComplete(nil)
            }
        }
    }

    /// Whether a generation is currently in progress
    var isGenerating: Bool {
        currentTask != nil && !currentTask!.isCancelled
    }

    // MARK: - Private Functions

    private func sanitizeImproveInstruction(_ instruction: String?) -> String? {
        instruction?.replacingOccurrences(
            of: QuickEditManager.shared.improvePrompt,
            with: "Improve"
        )
    }

    private func buildDescriptiveSegmentInstruction(
        previousInstruction: String?,
        action: String,
        selectedText: String
    ) -> String {
        let sanitizedPrevious = self.sanitizeImproveInstruction(previousInstruction)

        let descriptiveInstruction = "\(action): '\(selectedText)'"

        if let previous = sanitizedPrevious,
           !previous.isEmpty
        {
            return "\(previous) → \(descriptiveInstruction)"
        } else {
            return descriptiveInstruction
        }
    }
}
