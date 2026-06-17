//
//  QuickEditSelectionCoordinator.swift
//  Onit
//
//  Created by Kévin Naudin on 12/08/2025.
//

import Foundation
import AppKit
import Combine

@MainActor
class QuickEditSelectionCoordinator: ObservableObject {

    static let shared = QuickEditSelectionCoordinator()

    // MARK: - Dependencies

    private let selectionService = QuickEditSelectionService.shared
    private let diffService = QuickEditDiffService.shared
    private let selectionHintController = SelectionHintWindowController.shared
    private let unfreezeHintController = UnfreezeHintWindowController.shared

    // MARK: - State

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastError: Error?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupHintCallbacks()
    }

    // MARK: - Setup

    private func setupHintCallbacks() {
        selectionHintController.onFreeze = { [weak self] in
            self?.handleFreeze()
        }
        selectionHintController.onUnfreeze = { [weak self] in
            self?.handleUnfreezeFromSelectionHint()
        }
        selectionHintController.onUnfreezeAll = { [weak self] in
            self?.handleUnfreezeAll()
        }
        selectionHintController.onRetry = { [weak self] in
            Task { @MainActor in await self?.handleRetry() }
        }
        selectionHintController.onAIEdit = { [weak self] instruction in
            Task { @MainActor in await self?.handleAIEdit(instruction: instruction) }
        }
        selectionHintController.onVersionNavigate = { [weak self] index in
            self?.handleVersionNavigate(to: index)
        }
        selectionHintController.onDismissedByClickOutside = { [weak self] in
            self?.selectionService.updateSelection([])
        }
        selectionHintController.onDiffUndoHoverExit = { [weak self] in
            self?.selectionHintController.hide()
        }

        unfreezeHintController.onUnfreeze = { [weak self] range in
            self?.handleUnfreeze(range: range)
        }
        unfreezeHintController.onUnfreezeAll = { [weak self] in
            self?.handleUnfreezeAll()
        }
    }

    // MARK: - Public

    func reset() {
        QuickEditGenerationService.shared.cancelGeneration()
        selectionService.reset()
        selectionHintController.hide()
        unfreezeHintController.hide()
        isProcessing = false
        lastError = nil
    }

    func showSelectionHint(at screenPosition: CGPoint, for range: NSRange) {
        selectionHintController.show(
            at: screenPosition,
            for: range,
            context: determineHintContext(),
            versionInfo: selectionService.getSegmentVersionInfo(for: range),
            showUnfreezeAll: selectionService.frozenSegmentCount > 1
        )
    }

    func showUnfreezeHint(at screenPosition: CGPoint, for frozenRange: NSRange) {
        unfreezeHintController.show(
            at: screenPosition,
            for: frozenRange,
            showUnfreezeAll: selectionService.frozenSegmentCount > 1
        )
    }

    func showModifiedHint(at screenPosition: CGPoint, for modifiedRange: NSRange) {
        selectionHintController.show(
            at: screenPosition,
            for: modifiedRange,
            context: determineHintContext(),
            versionInfo: selectionService.getSegmentVersionInfo(for: modifiedRange),
            showUnfreezeAll: false
        )
    }

    func showDiffUndoHint(at screenPosition: CGPoint, for segment: DiffSegment) {
        selectionHintController.showDiffUndo(
            at: screenPosition,
            for: segment
        ) { [weak self] in
            self?.handleDiffUndo(segment: segment)
        }
    }

    func hideDiffUndoHint() {
        guard !selectionHintController.isMouseInPopup else { return }
        
        selectionHintController.hide()
    }

    private func handleDiffUndo(segment: DiffSegment) {
        guard let newResponse = diffService.undoSegment(segmentId: segment.id) else { return }

        QuickEditManager.shared.state.aiResponse = newResponse
        selectionHintController.hide()
    }

    func hideAllHints() {
        selectionHintController.hide()
        unfreezeHintController.hide()
    }

    // MARK: - Context

    private func determineHintContext() -> SelectionHintContext {
        return selectionService.selectionContainsFrozenText() ? .withFrozenSelection : .standard
    }

    // MARK: - Handlers

    private func handleFreeze() {
        guard !selectionService.selectedRanges.isEmpty,
              !selectionService.isEntireTextSelected() else { return }

        if selectionService.freezeSelection() {
            selectionHintController.hide()
        }
    }

    private func handleUnfreezeFromSelectionHint() {
        for range in selectionService.selectedRanges {
            if let frozenRange = selectionService.frozenRanges.first(where: {
                NSIntersectionRange($0, range).length > 0
            }) {
                selectionService.unfreeze(range: frozenRange)
            }
        }
        updateHintContextAfterUnfreeze()
    }

    private func handleUnfreeze(range: NSRange) {
        selectionService.unfreeze(range: range)
        unfreezeHintController.hide()

        if selectionHintController.isVisible {
            updateHintContextAfterUnfreeze()
        }
    }

    private func handleUnfreezeAll() {
        selectionService.unfreezeAll()
        unfreezeHintController.hide()

        if selectionHintController.isVisible {
            selectionHintController.updateContext(.standard, showUnfreezeAll: false)
        }
    }

    private func updateHintContextAfterUnfreeze() {
        if selectionService.hasFrozenText {
            selectionHintController.updateContext(.withFrozenSelection, showUnfreezeAll: selectionService.frozenSegmentCount > 1)
        } else {
            selectionHintController.updateContext(.standard, showUnfreezeAll: false)
        }
    }

    private func handleRetry() async {
        guard let originalRange = selectionService.selectedRanges.first,
              !isProcessing else { return }

        // Check access (auth + paywall) before generation
        let pendingOp = PendingOperation.segmentRetry(range: originalRange)
        guard await QuickEditManager.shared.checkAccessBeforeGeneration(pendingOperation: pendingOp) else {
            return
        }

        executeRetry(range: originalRange, showHintOnComplete: true)
    }

    private func handleAIEdit(instruction: String) async {
        guard let originalRange = selectionService.selectedRanges.first,
              !isProcessing,
              !instruction.isEmpty else { return }

        // Check access (auth + paywall) before generation
        let pendingOp = PendingOperation.segmentAIEdit(range: originalRange, instruction: instruction)
        guard await QuickEditManager.shared.checkAccessBeforeGeneration(pendingOperation: pendingOp) else {
            return
        }

        executeAIEdit(range: originalRange, instruction: instruction, showHintOnComplete: true)
    }

    private func showHintForSegmentAtPosition(_ segment: TextSegment, position: CGPoint) {
        selectionService.setUpdatingFromOperation(true)
        selectionService.updateSelection([segment.range])

        selectionHintController.show(
            at: position,
            for: segment.range,
            context: determineHintContext(),
            versionInfo: (segment.currentVersionIndex + 1, segment.versions.count),
            showUnfreezeAll: false
        )
    }

    private func handleVersionNavigate(to index: Int) {
        guard let range = selectionHintController.associatedRange,
              let updatedSegment = selectionService.navigateSegmentVersion(for: range, to: index) else { return }

        QuickEditManager.shared.state.aiResponse = selectionService.fullText
        selectionHintController.updateVersionInfo((updatedSegment.currentVersionIndex + 1, updatedSegment.versions.count))
        selectionHintController.updateAssociatedRange(updatedSegment.range)
        // Update selection to match the new segment range (for freeze/unfreeze operations)
        selectionService.updateSelection([updatedSegment.range])
    }

    // MARK: - Public Execute Methods (for retry after auth/subscription)

    /// Executes segment retry without access check (called after successful auth/subscription)
    func executeSegmentRetry(range: NSRange) async {
        guard !isProcessing else { return }
        selectionService.updateSelection([range])
        executeRetry(range: range, showHintOnComplete: false)
    }

    /// Executes segment AI-Edit without access check (called after successful auth/subscription)
    func executeSegmentAIEdit(range: NSRange, instruction: String) async {
        guard !isProcessing, !instruction.isEmpty else { return }
        selectionService.updateSelection([range])
        executeAIEdit(range: range, instruction: instruction, showHintOnComplete: false)
    }

    // MARK: - Private Execute Methods

    private func executeRetry(range: NSRange, showHintOnComplete: Bool) {
        let state = QuickEditManager.shared.state
        guard let context = state.createQuickEditRequest() else { return }

        let currentPosition = showHintOnComplete ? selectionHintController.lastPosition : nil

        isProcessing = true
        lastError = nil
        selectionHintController.hide()

        QuickEditGenerationService.shared.performSegmentRetry(
            range: range,
            context: context,
            state: state
        ) { [weak self] updatedSegment in
            guard let self = self else { return }
            self.isProcessing = false

            if let segment = updatedSegment {
                self.selectionService.updateSelection([segment.range])
                if showHintOnComplete, let position = currentPosition {
                    self.showHintForSegmentAtPosition(segment, position: position)
                }
            }
        }
    }

    private func executeAIEdit(range: NSRange, instruction: String, showHintOnComplete: Bool) {
        let state = QuickEditManager.shared.state
        guard let context = state.createQuickEditRequest() else { return }

        let currentPosition = showHintOnComplete ? selectionHintController.lastPosition : nil

        isProcessing = true
        lastError = nil
        selectionHintController.hide()

        QuickEditGenerationService.shared.performSegmentAIEdit(
            range: range,
            instruction: instruction,
            context: context,
            state: state
        ) { [weak self] updatedSegment in
            guard let self = self else { return }
            self.isProcessing = false

            if let segment = updatedSegment {
                self.selectionService.updateSelection([segment.range])
                if showHintOnComplete, let position = currentPosition {
                    self.showHintForSegmentAtPosition(segment, position: position)
                }
            }
        }
    }
}

// MARK: - QuickEditManager Extension

extension QuickEditManager {
    var selectionCoordinator: QuickEditSelectionCoordinator {
        QuickEditSelectionCoordinator.shared
    }
}
