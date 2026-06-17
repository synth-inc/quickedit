//
//  CustomPromptEditorWindow.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//

import SwiftUI

final class CustomPromptEditorWindow: CenteredWindow<CustomPromptEditorWindowView> {
    init(prompt: CustomPrompt?) {
        super.init(
            rootView: CustomPromptEditorWindowView(existingPrompt: prompt),
            windowLevel: .floating,
            windowSize: (width: 450, height: 520)
        )
    }
}
