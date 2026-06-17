//
//  ReferralLinkManager.swift
//  Onit
//
//  Created by Loyd Kim on 4/14/26.
//

import Combine
import Foundation

@MainActor
final class ReferralLinkManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ReferralLinkManager()

    // MARK: - Published Properties: Links

    @Published private(set) var links: [ReferralLink] = []
    @Published private(set) var maxLinks: Int = 6
    @Published private(set) var isFetchingLinks: Bool = false
    @Published private(set) var fetchLinksErrorMessage: String? = nil

    // MARK: - Published Properties: Add Link

    @Published private(set) var isAddingLink: Bool = false
    @Published var addLinkErrorMessage: String? = nil

    // MARK: - Published Properties: Update Link

    @Published private(set) var isUpdatingLink: Bool = false
    @Published var updateLinkErrorMessage: String? = nil

    // MARK: - Published Properties: Delete Link

    @Published private(set) var isDeletingLink: Bool = false
    @Published var deleteLinkErrorMessage: String? = nil
    
    // MARK: - Published Properties: Moderation

    @Published private(set) var moderationEntries: [ReferralLinkModerationEntry] = []
    @Published private(set) var isFetchingModerationEntries: Bool = false
    @Published private(set) var moderationEntriesErrorMessage: String? = nil
    
    @Published var moderationPage: Int = 1
    @Published private(set) var isFetchingModerationNextPage: Bool = false
    @Published private(set) var moderationHasMorePages: Bool = true
    
    @Published private(set) var moderationSelectedStatus: ReferralLinkStatus = .pending

    @Published private(set) var isModeratingLink: Bool = false
    @Published var moderateLinkErrorMessage: String? = nil

    #if DEBUG || ONIT_BETA
    @Published private(set) var pendingReferralLinkCount: Int = 0
    #endif

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    private init() {
        ReferralManager.shared.$uniqueReferralCode
            .removeDuplicates()
            .sink { [weak self] code in
                guard let self else { return }
                guard let code else {
                    self.reset()
                    return
                }
                self.fetchLinks(uniqueCode: code)
            }
            .store(in: &cancellables)

        #if DEBUG || ONIT_BETA
        Task { await fetchPendingLinkCount() }
        #endif
    }
    
    // MARK: - Public Variables
    
    var hasReachedMaxLinks: Bool {
        return links.count >= maxLinks
    }
    
    // MARK: - Private Variables
    
    private let moderationPageSize = 20

    // MARK: - Public Methods: Reset

    func reset() {
        links = []
        maxLinks = 6
        isFetchingLinks = false
        fetchLinksErrorMessage = nil
        
        isAddingLink = false
        addLinkErrorMessage = nil
        
        isUpdatingLink = false
        updateLinkErrorMessage = nil
        
        isDeletingLink = false
        deleteLinkErrorMessage = nil
        
        moderationEntries = []
        isFetchingModerationEntries = false
        moderationEntriesErrorMessage = nil
        moderationPage = 1
        isFetchingModerationNextPage = false
        moderationHasMorePages = true
        moderationSelectedStatus = .pending
        isModeratingLink = false
        moderateLinkErrorMessage = nil
        #if DEBUG || ONIT_BETA
        pendingReferralLinkCount = 0
        #endif
    }

    // MARK: - Public Methods: Fetch Links

    func fetchLinks(uniqueCode: String? = nil) {
        guard let code = uniqueCode ?? ReferralManager.shared.uniqueReferralCode
        else {
            return
        }

        isFetchingLinks = true
        fetchLinksErrorMessage = nil

        let client = FetchingClient()

        Task {
            do {
                let response = try await client.getReferralLinks(
                    uniqueCode: code
                )
                
                links = response.referralLinks
                maxLinks = response.maxLinks
            } catch {
                print("[ReferralLinkManager]: Failed to fetch links: \(error.localizedDescription)")
                fetchLinksErrorMessage = String.localized("Couldn't fetch your referral links.", table: "Settings")
            }

            isFetchingLinks = false
        }
    }

    // MARK: - Public Methods: Add Link

    func addLink(url: String) {
        guard let uniqueCode = ReferralManager.shared.uniqueReferralCode
        else {
            return
        }

        isAddingLink = true
        addLinkErrorMessage = nil

        let client = FetchingClient()

        Task {
            do {
                let newLink = try await client.addReferralLink(
                    uniqueCode: uniqueCode,
                    url: url
                )
                
                links.append(newLink)
            } catch {
                print("[ReferralLinkManager]: Failed to add link: \(error.localizedDescription)")
                addLinkErrorMessage = String.localized("Failed to add link. Please try again.", table: "Settings")
            }

            isAddingLink = false
        }
    }

    // MARK: - Public Methods: Update Link

    func updateLink(
        linkId: Int,
        url: String
    ) {
        guard let uniqueCode = ReferralManager.shared.uniqueReferralCode
        else {
            return
        }

        isUpdatingLink = true
        updateLinkErrorMessage = nil

        let oldUrl = links.first(where: { $0.id == linkId })?.url
        let client = FetchingClient()

        Task {
            do {
                let updatedLink = try await client.updateReferralLink(
                    linkId: linkId,
                    uniqueCode: uniqueCode,
                    url: url
                )

                if let existingReferralLinkIndex = links.firstIndex(where: { $0.id == linkId }) {
                    links[existingReferralLinkIndex] = updatedLink
                }

                if updatedLink.status != .approved,
                   let oldUrl
                {
                    ReferralManager.shared.removeLeaderboardEntryLink(url: oldUrl)
                }
            } catch {
                print("[ReferralLinkManager]: Failed to update link: \(error.localizedDescription)")
                updateLinkErrorMessage = String.localized("Failed to update link. Please try again.", table: "Settings")
            }

            isUpdatingLink = false
        }
    }

    // MARK: - Public Methods: Delete Link

    func deleteLink(
        linkId: Int,
        onSuccess: @escaping () -> Void
    ) {
        guard let uniqueCode = ReferralManager.shared.uniqueReferralCode
        else {
            return
        }

        isDeletingLink = true
        deleteLinkErrorMessage = nil

        let deletedUrl = links.first(where: { $0.id == linkId })?.url
        let client = FetchingClient()

        Task {
            do {
                let _ = try await client.deleteReferralLink(
                    linkId: linkId,
                    uniqueCode: uniqueCode
                )

                links.removeAll { $0.id == linkId }

                if let deletedUrl {
                    ReferralManager.shared.removeLeaderboardEntryLink(url: deletedUrl)
                }

                onSuccess()
            } catch {
                print("[ReferralLinkManager]: Failed to delete link: \(error.localizedDescription)")
                deleteLinkErrorMessage = String.localized("Failed to remove link. Please try again.", table: "Settings")
            }

            isDeletingLink = false
        }
    }

    // MARK: - Public Methods: Moderation

    #if DEBUG || ONIT_BETA
    func fetchPendingLinkCount() async {
        do {
            let client = FetchingClient()
            let response = try await client.getReferralLinksByStatus(
                status: .pending,
                productName: .dictation,
                page: 1,
                pageSize: 1
            )
            pendingReferralLinkCount = response.total
        } catch {
            // Non-critical — badge will show 0 if this fails
        }
    }
    #endif

    func setModerationStatus(_ status: ReferralLinkStatus) {
        moderationSelectedStatus = status
        resetAndFetchModerationEntries()
    }

    func resetAndFetchModerationEntries() {
        moderationEntries = []
        moderationEntriesErrorMessage = nil
        moderationPage = 1
        moderationHasMorePages = true
        
        fetchModerationEntries()
    }

    func fetchModerationEntries() {
        let isFirstPage = moderationPage == 1

        if isFirstPage {
            isFetchingModerationEntries = true
            isFetchingModerationNextPage = false
        } else {
            isFetchingModerationEntries = false
            isFetchingModerationNextPage = true
        }

        moderationEntriesErrorMessage = nil

        let client = FetchingClient()

        Task {
            do {
                let response = try await client.getReferralLinksByStatus(
                    status: moderationSelectedStatus,
                    productName: .dictation,
                    page: moderationPage,
                    pageSize: moderationPageSize
                )

                if isFirstPage {
                    moderationEntries = response.results
                } else {
                    moderationEntries.append(contentsOf: response.results)
                }

                moderationHasMorePages = response.results.count >= moderationPageSize
            } catch {
                print("[ReferralLinkManager]: Failed to fetch moderation entries: \(error.localizedDescription)")
                
                moderationEntriesErrorMessage = String.localized(
                    "Failed to fetch moderation entries.", 
                    table: "Settings"
                )
            }

            isFetchingModerationEntries = false
            isFetchingModerationNextPage = false
        }
    }

    func moderateLink(
        linkId: Int,
        status: ReferralLinkStatus,
        moderationReason: String?
    ) {
        isModeratingLink = true
        moderateLinkErrorMessage = nil

        let client = FetchingClient()

        Task {
            do {
                let moderatedLink = try await client.moderateReferralLink(
                    linkId: linkId,
                    status: status,
                    moderationReason: moderationReason
                )
                
                let moderationStatusChanged = moderatedLink.status != moderationSelectedStatus

                if moderationStatusChanged {
                    moderationEntries.removeAll { $0.id == linkId }
                } else if let existingModerationEntryIndex = moderationEntries.firstIndex(
                    where: { $0.id == linkId }
                ) {
                    let existingModerationEntry = moderationEntries[existingModerationEntryIndex]
                    
                    moderationEntries[existingModerationEntryIndex] = ReferralLinkModerationEntry(
                        id: existingModerationEntry.id,
                        createdAt: existingModerationEntry.createdAt,
                        updatedAt: existingModerationEntry.updatedAt,
                        url: existingModerationEntry.url,
                        status: moderatedLink.status,
                        moderationReason: moderatedLink.moderationReason,
                        referralId: existingModerationEntry.referralId,
                        referralUniqueCode: existingModerationEntry.referralUniqueCode,
                        referralProductName: existingModerationEntry.referralProductName,
                        referralDisplayName: existingModerationEntry.referralDisplayName,
                        referralOwnerId: existingModerationEntry.referralOwnerId
                    )
                }
            } catch {
                print("[ReferralLinkManager]: Failed to moderate link: \(error.localizedDescription)")
                
                moderateLinkErrorMessage = String.localized(
                    "Failed to moderate link. Please try again.",
                    table: "Settings"
                )
            }

            isModeratingLink = false
            #if DEBUG || ONIT_BETA
            await fetchPendingLinkCount()
            #endif
        }
    }
}
