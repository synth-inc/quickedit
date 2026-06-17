//
//  ReferralLink.swift
//  Onit
//
//  Created by Loyd Kim on 4/14/26.
//

enum ReferralLinkStatus: String, Codable, Equatable {
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
}

struct ReferralLink: Codable, Identifiable, Equatable {
    let id: Int
    let url: String
    let status: ReferralLinkStatus
    let moderationReason: String?
    let referralId: Int
}

struct ReferralLinksResponse: Codable {
    let referralLinks: [ReferralLink]
    let maxLinks: Int
}
