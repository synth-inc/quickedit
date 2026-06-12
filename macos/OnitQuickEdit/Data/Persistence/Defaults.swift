//
//  Defaults.swift
//  Onit
//
//  Created by Kévin Naudin on 29/01/2025.
//

import CoreGraphics
import Defaults
import Foundation

enum AuthFlowStatus: String, Defaults.Serializable {
    case hideAuth
    case showSignUp
    case showSignIn
}

enum FooterNotification: String, Defaults.Serializable {
    case discord
    case update
}

extension Defaults.Keys {
    
    // Remote model tokens
    static let openAIToken = Key<String?>("openAIToken", default: nil)
    static let anthropicToken = Key<String?>("anthropicToken", default: nil)
    static let xAIToken = Key<String?>("xAIToken", default: nil)
    static let googleAIToken = Key<String?>("googleAIToken", default: nil)
    static let deepSeekToken = Key<String?>("deepSeekToken", default: nil)
    static let perplexityToken = Key<String?>("perplexityToken", default: nil)
    static let cerebrasToken = Key<String?>("cerebrasToken", default: nil)
    
    // Remote model validation
    static let isOpenAITokenValidated = Key<Bool>("openAITokenValidated", default: false)
    static let isAnthropicTokenValidated = Key<Bool>("anthropicTokenValidated", default: false)
    static let isXAITokenValidated = Key<Bool>("xAITokenValidated", default: false)
    static let isGoogleAITokenValidated = Key<Bool>("googleAITokenValidated", default: false)
    static let isDeepSeekTokenValidated = Key<Bool>("deepSeekTokenValidated", default: false)
    static let isPerplexityTokenValidated = Key<Bool>("perplexityTokenValidated", default: false)
    static let isCerebrasTokenValidated = Key<Bool>("cerebrasTokenValidated", default: false)
    
    // Remote model usage
    static let useOpenAI = Key<Bool>("useOpenAI", default: true)
    static let useAnthropic = Key<Bool>("useAnthropic", default: true)
    static let useXAI = Key<Bool>("useXAI", default: true)
    static let useGoogleAI = Key<Bool>("useGoogleAI", default: true)
    static let useDeepSeek = Key<Bool>("useDeepSeek", default: true)
    static let usePerplexity = Key<Bool>("usePerplexity", default: true)
    static let useCerebras = Key<Bool>("useCerebras", default: true)

    static let streamResponse = Key<StreamResponseConfig>("streamResponse", default: StreamResponseConfig.default)

    // Dialogs closed
    static let closedNoLocalModels = Key<Bool>("closedNoLocalModels", default: false)

    static let remoteModel = Key<AIModel?>("remoteModel", default: nil)
    static let localModel = Key<String?>("localModel", default: nil)
    static let mode = Key<InferenceMode>("mode", default: .remote)
    static let availableLocalModels = Key<[String]>("availableLocalModels", default: [])
    static let availableRemoteModels = Key<[AIModel]>("availableRemoteModels", default: [])
    static let availableCustomProviders = Key<[CustomProvider]>(
        "availableCustomProvider", default: [])
    static let userRemovedRemoteModels = Key<[AIModel]>("userRemovedRemoteModels", default: [])
    static let userAddedRemoteModels = Key<[AIModel]>("userAddedRemoteModels", default: [])

    // Stores unique model identifiers in the format "provider-id" or "customProviderName-id" for custom providers
    static let visibleModelIds = Key<Set<String>>("visibleModelIds", default: Set([]))
    static let visibleLocalModels = Key<Set<String>>("visibleLocalModels", default: Set([]))
    static let hasPerformedModelIdMigration = Key<Bool>(
        "hasPerformedModelIdMigration", default: false)

    static let localEndpointURL = Key<URL>(
        "localEndpointURL", default: URL(string: "http://localhost:11434")!)

    // Feature flags
    static let usePinnedMode = Key<Bool?>("use_screen_mode_with_accessibility", default: nil)
    
    static let autoContextFromCurrentWindow = Key<Bool>("autoContextFromCurrentWindow", default: true)
    static let autoContextFromHighlights = Key<Bool>("autoContextFromHighlights", default: true)

    // General settings
    static let appAppearance = Key<AppAppearance>("appAppearance", default: .system)
    static let launchOnStartupRequested = Key<Bool>("launchOnStartupRequested", default: false)
    static let hideDockIcon = Key<Bool>("hideDockIcon", default: false)
    static let fontSize = Key<Double>("fontSize", default: 14.0)
    static let lineHeight = Key<Double>("lineHeight", default: 1.5)

    static let settingsPage = Key<SettingsPage>("settingsPage", default: .general)

    // Local model advanced options
    static let localKeepAlive = Key<String?>("localKeepAlive", default: nil)
    static let localNumCtx = Key<Int?>("localNumCtx", default: nil)
    static let localTemperature = Key<Double?>("localTemperature", default: nil)
    static let localTopP = Key<Double?>("localTopP", default: nil)
    static let localTopK = Key<Int?>("localTopK", default: nil)
    static let localRequestTimeout = Key<TimeInterval?>("localRequestTimeout", default: 60.0)
    
    // Onboarding
    static let authFlowStatus = Key<AuthFlowStatus>("authFlowStatus", default: .hideAuth)
    static let currentOnboardingStep = Key<OnboardingStep?>("currentOnboardingStep", default: nil)
    static let onboardingDismissed = Key<Bool>("onboardingDismissed", default: false)
    static let mainOnboardingCompleted = Key<Bool>("mainOnboardingCompleted", default: false)
    static let quickEditSpecificStepsCompleted = Key<Bool>("quickEditSpecificStepsCompleted", default: false)
    static let quickEditTranslationSpecificStepsCompleted = Key<Bool>("quickEditTranslationSpecificStepsCompleted", default: false)
    static let onboardingAuthSkipped = Key<Bool>("onboardingAuthSkipped", default: false)

    // Alerts
    static let showTwoWeekProTrialEndedAlert = Key<Bool>("showTwoWeekProTrialEndedAlert", default: false)
    static let hasClosedTrialEndedAlert = Key<Bool>("hasClosedTrialEndedAlert", default: false)
    
    // Notifications
    static let footerNotifications = Key<[FooterNotification]>("footerNotifications", default: [FooterNotification.discord])

    // Stop generation behavior
    static let stopMode = Key<StopMode>("stopMode", default: .removePartial)
    static let stopModeUserConfigured = Key<Bool>("stopModeUserConfigured", default: false)
    
    // QuickEdit
    #if DEBUG || ONIT_BETA
    static let hideBugReportEmoji = Key<Bool>("hideBugReportEmoji", default: false)
    #endif
    static let quickEditConfig = Key<QuickEditConfig>("quickEditConfig", default: .default)
    static let quickEditMode = Key<InferenceMode>("quickEditMode", default: .remote)
    static let quickEditRemoteModel = Key<AIModel?>("quickEditRemoteModel", default: nil)
    static let quickEditLocalModel = Key<String?>("quickEditLocalModel", default: nil)
    static let quickEditShowHistoryWithoutTyping = Key<Bool>("quickEditShowHistoryWithoutTyping", default: false)
    static let quickEditSmartPositioning = Key<Bool>("quickEditSmartPositioning", default: true)
    static let quickEditAlwaysShowDiffViewOnImprove = Key<Bool>("quickEditAlwaysShowDiffViewOnImprove", default: false)

    // Screen recording
    static let screenRecordingPermissionAsked = Key<Bool>("screenRecordingPermissionAsked", default: false)
    
    // Feature Disable (QuickEdit)
    static let featureDisableRules = Key<[FeatureDisableRule]>("featureDisableRules", default: [])
    static let ignoredFeatureDisableRules = Key<[IgnoredFeatureDisableRule]>("ignoredFeatureDisableRules", default: [])
    static let quickEditDisabledInPrivateBrowser = Key<Bool>("quickEditDisabledInPrivateBrowser", default: true)
    static let capsLockModifierShortcuts = Key<[String]>("capsLockModifierShortcuts", default: [])

    // Translation
    static let isTranslationBuild = Key<Bool>("isTranslationBuild", default: false)
    static let translationBuildLanguageCode = Key<String?>("translationBuildLanguageCode", default: nil)
    static let translationSourceLanguageCode = Key<String?>("translationSourceLanguageCode", default: nil)
    static let translationTargetLanguageCode = Key<String?>("translationTargetLanguageCode", default: nil)
    
}

extension NSRect: Defaults.Serializable {

}
