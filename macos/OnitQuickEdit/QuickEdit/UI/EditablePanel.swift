//
//  EditablePanel.swift
//  Onit
//
//  Created by Kévin Naudin on 11/24/2025.
//

import AppKit

class EditablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setup(
        delegate: NSWindowDelegate? = nil,
        addShadow: Bool = true,
        clickThrough: Bool = false
    ) {
        styleMask = [.nonactivatingPanel, .borderless]
        isOpaque = false
        backgroundColor = NSColor.clear
        level = .screenSaver
        hasShadow = addShadow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isReleasedWhenClosed = false
        ignoresMouseEvents = clickThrough
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        self.delegate = delegate
    }
}
