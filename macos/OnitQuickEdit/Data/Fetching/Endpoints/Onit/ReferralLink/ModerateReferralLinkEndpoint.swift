//
//  ModerateReferralLinkEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 4/14/26.
//

import Foundation

extension FetchingClient {
    func moderateReferralLink(
        linkId: Int,
        status: ReferralLinkStatus,
        moderationReason: String? = nil
    ) async throws -> ReferralLink {
        let endpoint = ModerateReferralLinkEndpoint(
            linkId: linkId,
            status: status,
            moderationReason: moderationReason
        )
        return try await execute(endpoint)
    }
}

struct ModerateReferralLinkEndpoint: Endpoint {
    typealias Request = ModerateReferralLinkRequest
    typealias Response = ReferralLink

    var baseURL: URL { OnitServer.baseURL }

    let linkId: Int

    var path: String { "/v1/referral/moderation/links/\(linkId)" }
    var getParams: [String: String]? { nil }
    var method: HTTPMethod { .patch }
    var token: String? { TokenManager.token }

    let status: ReferralLinkStatus
    let moderationReason: String?

    var requestBody: Request? {
        ModerateReferralLinkRequest(status: status, moderationReason: moderationReason)
    }

    var additionalHeaders: [String: String]? { nil }
    var timeout: TimeInterval? { nil }
}

struct ModerateReferralLinkRequest: Codable {
    let status: ReferralLinkStatus
    let moderationReason: String?
}
