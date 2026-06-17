//
//  DebugManager.swift
//  Onit
//
//  Created by Kévin Naudin on 02/04/2025.
//

import SwiftUI

@MainActor
class DebugManager: ObservableObject {

    // MARK: - Singleton

    static let shared = DebugManager()

    // MARK: - Properties

    @Published var showDebugWindow = false
    @Published var debugText: String = ""

    // MARK: - Initialization

    private init() { }
}
