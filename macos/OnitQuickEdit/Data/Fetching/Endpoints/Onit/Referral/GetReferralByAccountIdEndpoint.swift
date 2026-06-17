//
//  GetReferralByAccountIdEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 3/19/26.
//

import Foundation

extension FetchingClient {
    /// Retrieves a referral for the authenticated user's account and the specified product.
    func getReferralByAccountId(productName: ReferralProductName) async throws -> Referral {
        let endpoint = GetReferralByAccountIdEndpoint(productName: productName)
        return try await execute(endpoint)
    }
}

struct GetReferralByAccountIdEndpoint: Endpoint {
    typealias Request = EmptyRequest

    typealias Response = Referral

    var baseURL: URL { OnitServer.baseURL }

    var path: String { "/v1/referral/account" }

    let productName: ReferralProductName

    var getParams: [String : String]? {
        ["productName": productName.rawValue]
    }

    var method: HTTPMethod { .get }

    var token: String? { TokenManager.token }

    var requestBody: Request? { nil }

    var additionalHeaders: [String : String]? { nil }

    var timeout: TimeInterval? { nil }
}
