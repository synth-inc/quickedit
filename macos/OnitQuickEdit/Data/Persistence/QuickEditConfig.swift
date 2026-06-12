//
//  QuickEditConfig.swift
//  Onit
//
//  Created by Kévin Naudin on 06/20/2025.
//

import Foundation
import Defaults

struct QuickEditConfig: Codable, Defaults.Serializable {
    var isEnabled: Bool
    var showHint: Bool
    var showCustomPrompts: Bool
    var shouldCaptureTrainingData: Bool
    var enableAutoContext: Bool
    var enableNonAccessibilityTrigger: Bool

    static let `default` = QuickEditConfig(
        isEnabled: false,
        showHint: true,
        showCustomPrompts: true,
        shouldCaptureTrainingData: false,
        enableAutoContext: true,
        enableNonAccessibilityTrigger: false
    )
}
