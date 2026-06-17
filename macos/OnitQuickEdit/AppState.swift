//
//  AppState.swift
//  Onit
//
//  Created by Kévin Naudin on 02/04/2025.
//

import Combine
import Defaults
import DefaultsMacros
import Sparkle
import SwiftUI

@MainActor
@Observable
class AppState: NSObject, SPUUpdaterDelegate {
    // MARK: - Singleton
    
    static let shared = AppState()
    
    private var modelProvidersManager = ModelProvidersManager.shared
    private var authManager = AuthManager.shared
    
    // MARK: - Properties

    var showMenuBarExtra: Bool = false
    var updater: SPUStandardUpdaterController!
    var isUpdateAvailable: Bool = false
    var availableUpdateVersion: String? = nil


    var remoteFetchFailed: Bool = false
    var localFetchFailed: Bool = false
    
    private var fetchSubscriptionTask: Task<Void, Never>?
    
    var subscription: Subscription?
//    var subscriptionActive: Bool { subscription?.status == "active" || subscription?.status == "trialing" }
    
    var subscriptionCanceled: Bool {
        if let canceled = subscription?.cancelAtPeriodEnd {
            return canceled
        } else {
            return false
        }
    }
    
    var subscriptionStatus: String? {
        if authManager.userLoggedIn && subscription == nil {
            return SubscriptionStatus.free
        } else if let subscription = subscription {
            switch subscription.status {
            case "trialing":
                return SubscriptionStatus.trialing
            case "active":
                return SubscriptionStatus.active
            default:
                // Stripe statuses: Canceled, Incomplete, Incomplete Expired, Past Due, Unpaid, and Paused
                return SubscriptionStatus.free
            }
        } else {
            return nil
        }
    }
    var showFreeLimitAlert: Bool = false
    var showProLimitAlert: Bool = false
    var subscriptionPlanError: String = ""
    
    var showAddModelAlert: Bool = false
    
    private var authCancellable: AnyCancellable? = nil

    // MARK: - App Status Properties

    /// Status dot color in the menu bar (reactive)
    var statusDotColor: AppStatusDotColor = .green

    /// Main status message (first line of the menu)
    var statusMessage: AppStatusMessage = .running

    /// Badge count for Settings Setup page (nil = no badge)
    var setupBadgeCount: Int? = nil

    /// Cancellables for status observers
    @ObservationIgnored
    var statusObserverCancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    
    override init() {
        super.init()
        
        // Used for updating subscription variables in response to account updates.
        authCancellable = AuthManager.shared.$account
            .receive(on: DispatchQueue.main)
            .sink { [weak self] account in
                if let self = self {
                    if account == nil {
                        fetchSubscriptionTask?.cancel()
                        fetchSubscriptionTask = nil
                        subscription = nil
                    } else {
                        fetchSubscriptionTask?.cancel()
                        fetchSubscriptionTask = Task {
                            subscription = try? await FetchingClient().getSubscription()
                        }
                    }
                }
            }
        
        // Initialize Sparkle updater for showing/removing update available footer notification.
        updater = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        Task {
            await fetchLocalModels()
            await fetchRemoteModels()

            // This handles an edge case where Ollama is running but there is no internet connection
            // We put the user in localmode so they can use the product.
            // We don't do the opposite, because we don't want to put the product in remote mode without them knowing.
            if !Defaults[.availableLocalModels].isEmpty && Defaults[.availableRemoteModels].isEmpty
            {
                Defaults[.mode] = .local
            }
        }

        // Setup status observers for reactive status updates
        setupStatusObservers()
    }
    
    // MARK: - Functions

    @MainActor
    func fetchLocalModels() async {
        do {
            let models = try await FetchingClient().getLocalModels()

            // Handle local model selection
            let localModel = Defaults[.localModel]

            Defaults[.availableLocalModels] = models
            
            // Initialize visible local models if empty (first time or after being cleared)
            if Defaults[.visibleLocalModels].isEmpty && !models.isEmpty {
                Defaults[.visibleLocalModels] = Set(models)
            } else {
                // Update visible models to only include currently available models
                let currentVisible = Defaults[.visibleLocalModels]
                Defaults[.visibleLocalModels] = currentVisible.intersection(Set(models))
            }
            
            if models.isEmpty {
                Defaults[.localModel] = nil
            } else if localModel == nil || !models.contains(localModel!) {
                // Choose from visible models if available
                let visibleModels = Defaults[.visibleLocalModels]
                if let firstVisibleModel = visibleModels.first {
                    Defaults[.localModel] = firstVisibleModel
                }
            }
            localFetchFailed = false

            // Reset the closedNoLocalModels flag when local models are successfully fetched.
            Defaults[.closedNoLocalModels] = false
        } catch {
            print("Error fetching local models:", error)
            localFetchFailed = true
            Defaults[.availableLocalModels] = []
            Defaults[.localModel] = nil
        }
    }

    @MainActor
    func fetchRemoteModels() async {
        do {
            var models = try await AIModel.fetchModels()
            
            /// Removing user-removed remote models from fetched result.
            let userRemovedRemoteModelUniqueIds = Set(Defaults[.userRemovedRemoteModels].map { $0.uniqueId })
            models.removeAll { userRemovedRemoteModelUniqueIds.contains($0.uniqueId) }
            
            /// Updating fetched remote models with user-added remote models.
            for userAddedRemoteModel in Defaults[.userAddedRemoteModels] {
                if let existingModelIndex = models.firstIndex(where: { $0.uniqueId == userAddedRemoteModel.uniqueId }) {
                    models[existingModelIndex] = userAddedRemoteModel
                } else {
                    models.append(userAddedRemoteModel)
                }
            }

            // This means we've never successfully fetched before
            if Defaults[.availableRemoteModels].isEmpty {
                if Defaults[.visibleModelIds].isEmpty {
                    Defaults[.visibleModelIds] = Set(
                        models.filter { $0.defaultOn }.map { $0.uniqueId })
                }

                Defaults[.availableRemoteModels] = models
                if !listedModels.isEmpty {
                    Defaults[.remoteModel] = listedModels.first
                }
            } else {

                // Migrate legacy model IDs if needed
                if !Defaults[.hasPerformedModelIdMigration] {
                    let legacyIds = Defaults[.visibleModelIds]
                    let migratedIds = AIModel.migrateVisibleModelIds(
                        models: Defaults[.availableRemoteModels], legacyIds: legacyIds)
                    Defaults[.visibleModelIds] = migratedIds
                    Defaults[.hasPerformedModelIdMigration] = true
                }

                // Update the availableRemoteModels with the newly fetched models
                let newModelIds = Set(models.map { $0.id })
                
                let existingModelIds = Set(Defaults[.availableRemoteModels].map { $0.id })

                let newModels = models.filter { !existingModelIds.contains($0.id) }
                var deprecatedModels = Defaults[.availableRemoteModels].filter {
                    !newModelIds.contains($0.id)
                }
                for index in models.indices where newModels.contains(models[index]) {
                    models[index].isNew = true
                }

                for index in deprecatedModels.indices {
                    deprecatedModels[index].isDeprecated = true
                }

                // We only save deprecated models if the user has them visibile. Otherwise, quietly remove them from the list.
                let visibleModelIds = Set(Defaults[.visibleModelIds])
                let visibleDeprecatedModels = deprecatedModels.filter {
                    visibleModelIds.contains($0.uniqueId)
                }

                remoteFetchFailed = false
                Defaults[.availableRemoteModels] = models + visibleDeprecatedModels
                if visibleModelIds.isEmpty {
                    Defaults[.visibleModelIds] = Set(
                        (models + visibleDeprecatedModels).filter { $0.defaultOn }.map {
                            $0.uniqueId
                        })
                }

                if !listedModels.isEmpty
                    && (Defaults[.remoteModel] == nil
                        || !Defaults[.availableRemoteModels].contains(Defaults[.remoteModel]!))
                {
                    Defaults[.remoteModel] = Defaults[.availableRemoteModels].first
                }
            }

        } catch {
            print("Error fetching remote models:", error)
            remoteFetchFailed = true
        }
    }
    
    func handleDeeplink(_ url: URL) {
        guard url.scheme == "onit" else {
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Invalid URL: \(url)")
            return
        }
        
        // Handle different deeplink actions based on path
        switch components.path {
        case "/update", "/check-for-updates":
            handleUpdateDeeplink()
        default:
            if components.host == "settings" {
                // onit-quickedit://settings/<page> — host is "settings", path is "/<page>"
                let pagePath = String(components.path.dropFirst()) // drop leading "/"
                if let page = SettingsPage.allCases.first(where: { $0.deepLinkPath == pagePath }) {
                    NSApp.activate(ignoringOtherApps: true)
                    AppWindowManager.shared.showWindow(settingsPage: page)
                }
            } else {
                // For backwards compatibility, if no path is specified, assume it's a token login
                authManager.handleTokenLogin(url)
            }
        }
    }
    
    func handleUpdateDeeplink() {
        // Activate the app to bring it to the foreground
        NSApp.activate(ignoringOtherApps: true)
        checkForAvailableUpdateWithDownload()
    }
    
    // MARK: - Remote Models

    @ObservableDefault(.availableRemoteModels)
    @ObservationIgnored
    var availableRemoteModels: [AIModel]
    
    var listedModels: [AIModel] {
        var models = availableRemoteModels.filter {
            Defaults[.visibleModelIds].contains($0.uniqueId)
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.openAI) {
            models = models.filter { $0.provider != .openAI }
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.anthropic) {
            models = models.filter { $0.provider != .anthropic }
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.xAI) {
            models = models.filter { $0.provider != .xAI }
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.googleAI) {
            models = models.filter { $0.provider != .googleAI }
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.deepSeek) {
            models = models.filter { $0.provider != .deepSeek }
        }
        
        if !modelProvidersManager.getCanAccessStandardRemoteProvider(.perplexity) {
            models = models.filter { $0.provider != .perplexity }
        }

        // Filter out models from disabled custom providers
        for customProvider in modelProvidersManager.availableCustomProviders {
            models = models.filter { model in
                if model.customProviderName == customProvider.name {
                    return customProvider.isEnabled
                }
                return true
            }
        }

        return models
    }

//    var remoteNeedsSetup: Bool {
//        listedModels.isEmpty
//    }
    
}

// MARK: - App Update Listeners

extension AppState {
    func removeDiscordFooterNotifications() {
        Defaults[.footerNotifications].removeAll { notification in
            if case .discord = notification {
                return true
            }
            return false
        }
    }
    
    func checkForAvailableUpdateWithDownload() {
        self.updater.updater.checkForUpdates()
    }
    
    private func addUpdateFooterNotification() {
        if !Defaults[.footerNotifications].contains(.update) {
            Defaults[.footerNotifications].append(.update)
        }
    }
    
    nonisolated func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        let versionString = item.versionString
        Task { @MainActor in
            availableUpdateVersion = versionString
            isUpdateAvailable = true
            addUpdateFooterNotification()
        }
    }
    
    func removeUpdateFooterNotifications() {
        Defaults[.footerNotifications].removeAll { notification in
            if case .update = notification {
                return true
            }
            return false
        }
    }
    
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            isUpdateAvailable = false
            removeUpdateFooterNotifications()
        }
    }
}
