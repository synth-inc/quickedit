//
//  Referral.swift
//  Onit
//
//  Created by Loyd Kim on 3/19/26.
//

import Foundation

enum ReferralProductName: String, Codable {
    case quickEdit = "QuickEdit"
    case dictation = "Dictation"
    case sidekick = "Sidekick"
    case autocomplete = "Autocomplete"
}

struct Referral: Codable {
    let id: Int
    let uniqueCode: String
    let productName: ReferralProductName
    let displayName: String
    let accountId: Int?
}

struct ReferralJourney: Codable {
    let id: Int
    let referenceId: String
    let downloadedAt: String?
    let installedAt: String?
    let signedUpAt: String?
    let referralId: Int
}

struct CompletedInvitationsCount: Codable {
    let count: Int
}

struct LeaderboardEntryLink: Codable {
    let url: String
}

struct LeaderboardEntry: Codable {
    let id: Int
    let displayName: String
    let completedInvitations: Int
    let approvedLinks: [LeaderboardEntryLink]
}

struct LeaderboardRank: Codable {
    let rank: Int?
    let displayName: String
    let completedInvitations: Int
}

struct ReferrerInfo: Codable {
    let id: Int
    let uniqueCode: String
    let productName: ReferralProductName
    let displayName: String
    let accountId: Int?
}
