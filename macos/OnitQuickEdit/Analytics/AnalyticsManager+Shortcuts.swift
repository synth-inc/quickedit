//
//  AnalyticsManager+Shortcuts.swift
//  Onit
//
//  Created by Kévin Naudin on 10/06/2026.
//

import PostHog

extension AnalyticsManager {

    static func shortcutPressed(for shortcutName: String, panelOpened: Bool) {
        var properties = Self.getCommonProperties()

        properties["shortcut_name"] = shortcutName
        properties["panel_opened"] = panelOpened

        PostHogSDK.shared.capture("shortcut_pressed", properties: properties)
    }
}
