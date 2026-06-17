//
//  QuickEditConstants.swift
//  Onit
//
//  Created by Kévin Naudin on 11/25/2025.
//

import Foundation
import CoreGraphics

/// Centralized constants for QuickEdit UI dimensions
enum QuickEditConstants {
    // MARK: - Window Dimensions

    /// Max width of the QuickEdit window
    static let maxWindowWidth: CGFloat = 480

    /// Max height of the QuickEdit window (container)
    static let maxWindowHeight: CGFloat = 480

    /// Padding between the text and the QuickEdit window
    static let windowPadding: CGFloat = 8

    // MARK: - Hint Dimensions

    /// Approximate width of the hint view
    static let hintWidth: CGFloat = 166

    /// Approximate height of the hint view
    static let hintHeight: CGFloat = 26

    static let hintPadding: CGFloat = 4
    
    /// Search padding in the X direction (left and right of text frame)
    static let hintSearchPaddingX: CGFloat = 200

    /// Search padding in the Y direction (above and below text frame)
    static let hintSearchPaddingY: CGFloat = 50

}
