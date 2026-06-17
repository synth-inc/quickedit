//
//  SelectionHintViewModel.swift
//  Onit
//
//  Created by Kévin Naudin on 12/09/2025.
//

import SwiftUI

@MainActor
class SelectionHintViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var mode: SelectionHintMode = .actions
    @Published var context: SelectionHintContext = .standard
    @Published var aiEditText: String = ""
    @Published var versionInfo: (current: Int, total: Int)?
    @Published var showUnfreezeAll: Bool = false

    // MARK: - Callbacks

    var onFreeze: () -> Void = {}
    var onUnfreeze: () -> Void = {}
    var onUnfreezeAll: () -> Void = {}
    var onRetry: () -> Void = {}
    var onAIEdit: ((String) -> Void)?
    var onVersionNavigate: ((Int) -> Void)?
    var onDismiss: () -> Void = {}
    var onAIEditModeEnter: (() -> Void)?
    var onDiffUndo: () -> Void = {}
    var onDiffUndoHoverExit: () -> Void = {}

    // MARK: - Actions

    func onAIEditTap() {
        mode = .aiEdit
        onAIEditModeEnter?()
    }

    func onAIEditSubmit() {
        guard !aiEditText.isEmpty else { return }
        onAIEdit?(aiEditText)
        aiEditText = ""
        mode = .actions
    }

    func onAIEditCancel() {
        aiEditText = ""
        mode = .actions
    }

    func onPreviousVersion() {
        guard let info = versionInfo, info.current > 1 else { return }
        onVersionNavigate?(info.current - 2) // 0-indexed
    }

    func onNextVersion() {
        guard let info = versionInfo, info.current < info.total else { return }
        onVersionNavigate?(info.current) // 0-indexed
    }

    // MARK: - Configuration

    func configure(
        context: SelectionHintContext,
        versionInfo: (current: Int, total: Int)?,
        showUnfreezeAll: Bool,
        onFreeze: @escaping () -> Void,
        onUnfreeze: @escaping () -> Void,
        onUnfreezeAll: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onAIEdit: @escaping (String) -> Void,
        onVersionNavigate: @escaping (Int) -> Void,
        onDismiss: @escaping () -> Void,
        onAIEditModeEnter: @escaping () -> Void
    ) {
        self.context = context
        self.versionInfo = versionInfo
        self.showUnfreezeAll = showUnfreezeAll
        self.onFreeze = onFreeze
        self.onUnfreeze = onUnfreeze
        self.onUnfreezeAll = onUnfreezeAll
        self.onRetry = onRetry
        self.onAIEdit = onAIEdit
        self.onVersionNavigate = onVersionNavigate
        self.onDismiss = onDismiss
        self.onAIEditModeEnter = onAIEditModeEnter
    }

    func updateContext(_ context: SelectionHintContext, showUnfreezeAll: Bool = false) {
        self.context = context
        self.showUnfreezeAll = showUnfreezeAll
    }

    func reset() {
        mode = .actions
        context = .standard
        aiEditText = ""
        versionInfo = nil
        showUnfreezeAll = false
    }
}
