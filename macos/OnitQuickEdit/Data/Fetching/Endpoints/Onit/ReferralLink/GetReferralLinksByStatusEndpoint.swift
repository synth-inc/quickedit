//
//  GetReferralLinksByStatusEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 4/14/26.
//

import Foundation

extension FetchingClient {
    func getReferralLinksByStatus(
        status: ReferralLinkStatus,
        productName: ReferralProductName,
        page: Int? = nil,
        pageSize: Int? = nil
    ) async throws -> ReferralLinksByStatusResponse {
        let endpoint = GetReferralLinksByStatusEndpoint(
            status: status,
            productName: productName,
            page: page,
            pageSize: pageSize
        )
        return try await execute(endpoint)
    }
}

struct ReferralLinksByStatusResponse: Codable {
    let results: [ReferralLinkModerationEntry]
    let total: Int
}

struct ReferralLinkModerationEntry: Codable {
    let id: Int
    let createdAt: String
    let updatedAt: String
    let url: String
    let status: ReferralLinkStatus
    let moderationReason: String?
    let referralId: Int
    let referralUniqueCode: String
    let referralProductName: ReferralProductName
    let referralDisplayName: String
    let referralOwnerId: Int?
}

struct GetReferralLinksByStatusEndpoint: Endpoint {
    typealias Request = EmptyRequest
    typealias Response = ReferralLinksByStatusResponse

    var baseURL: URL { OnitServer.baseURL }
    var path: String { "/v1/referral/moderation/links" }

    let status: ReferralLinkStatus
    let productName: ReferralProductName
    let page: Int?
    let pageSize: Int?

    var getParams: [String: String]? {
        var params: [String: String] = [
            "status": status.rawValue,
            "productName": productName.rawValue,
        ]
        if let page { params["page"] = String(page) }
        if let pageSize { params["pageSize"] = String(pageSize) }
        return params
    }

    var method: HTTPMethod { .get }
    var token: String? { TokenManager.token }
    var requestBody: Request? { nil }
    var additionalHeaders: [String: String]? { nil }
    var timeout: TimeInterval? { nil }
}
