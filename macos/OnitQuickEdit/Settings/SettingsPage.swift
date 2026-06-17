//
//  SettingsPage.swift
//  Onit
//
//  Created by Loyd Kim on 9/2/25.
//

import Defaults
import SwiftUI

private var legacyFeaturesEnabled: Bool {
    Defaults[.quickEditConfig].isEnabled
}

enum SettingsPage: CaseIterable, Codable, Defaults.Serializable {
    // MARK: - Cases

    case general
    case accountAndBilling
    case setup
//    case shortcuts
    case about

    case quickEditPrompts
    case disabledAppsAndSites
    #if DEBUG || ONIT_BETA
    case quickEditDev
    #endif

    #if DEBUG || ONIT_BETA
    case experimental
    #endif

    // MARK: - CaseIterable

    static var rootCases: [SettingsPage] {
        var cases: [SettingsPage] = [
            .general,
            .accountAndBilling,
            .setup
        ]

        cases.append(.about)
        return cases
    }

    /// QuickEdit-specific pages (visible when quickEditConfig.isEnabled)
    static var quickEditCases: [SettingsPage] {
        #if DEBUG || ONIT_BETA
        return [
            .quickEditPrompts,
            .disabledAppsAndSites,
            .quickEditDev
        ]
        #else
        return [
            .quickEditPrompts,
            .disabledAppsAndSites
        ]
        #endif
    }

    #if DEBUG || ONIT_BETA
    /// Development pages (DEBUG/BETA only)
    static var devCases: [SettingsPage] {
        return [.experimental]
    }
    #endif

    // MARK: - Variables

    @MainActor
    var name: String {
        switch self {
        case .general:
            return String.localized("General", table: "Settings")
        case .accountAndBilling:
            return legacyFeaturesEnabled
                ? String.localized("Account & Billing", table: "Settings")
                : String.localized("Account", table: "Settings")
        case .setup:
            return String.localized("Setup", table: "Settings")
//        case .shortcuts:
//            return String.localized("Shortcuts", table: "Settings")
        case .about:
            return String.localized("About", table: "Settings")

        case .quickEditPrompts:
            return String.localized("Prompts", table: "Settings")
        case .disabledAppsAndSites:
            return String.localized("Disabled Apps", table: "Settings")

        #if DEBUG || ONIT_BETA
        case .experimental:
            return String.localized("Experimental", table: "Settings")
        case .quickEditDev:
            return String.localized("Dev", table: "Settings")
        #endif
        }
    }

    var hasCustomScrolling: Bool {
        return false
    }

    /// Pages that render their own custom title bar (with inline action buttons)
    /// in their own body, opting out of `SettingsWindowPages`' default header.
    var rendersOwnHeader: Bool {
        switch self {
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        /// Root
        case .general:
            return "gearshape.fill"
        case .accountAndBilling:
            return "person.fill"
        case .setup:
            return "hammer.fill"
        case .about:
            return "info.circle.fill"
        /// QuickEdit
        case .quickEditPrompts:
            return "bubble.fill"
        case .disabledAppsAndSites:
            return "hourglass.tophalf.filled"
        /// Dev
        #if DEBUG || ONIT_BETA
        case .quickEditDev:
            return "gearshape.fill"
        case .experimental:
            return "gearshape.fill"
        #endif
        }
    }

    /// URL path segment for deep linking via `onit-quickedit://settings/<deepLinkPath>`.
    var deepLinkPath: String {
        switch self {
        case .general: return "general"
        case .accountAndBilling: return "account"
        case .setup: return "setup"
        case .about: return "about"
        case .quickEditPrompts: return "prompts"
        case .disabledAppsAndSites: return "disabled-apps"
        #if DEBUG || ONIT_BETA
        case .quickEditDev: return "quickedit-dev"
        case .experimental: return "experimental"
        #endif
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .setup,
                .about,
                .quickEditPrompts:
            return Color.blue
            
        case .disabledAppsAndSites:
            return Color.blue350
            
        case .accountAndBilling:
            return Color.green

        #if DEBUG || ONIT_BETA
        case .quickEditDev,
                .experimental:
            return Color.gray
        #endif
            
        default:
            return Color.gray
        }
    }
}
