//
//  GetReferralByUniqueCodeEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 3/19/26.
//

import Foundation

extension FetchingClient {
    /// Retrieves a referral by its unique code.
    func getReferralByUniqueCode(uniqueCode: String) async throws -> Referral {
        let endpoint = GetReferralByUniqueCodeEndpoint(uniqueCode: uniqueCode)
        return try await execute(endpoint)
    }
}

struct GetReferralByUniqueCodeEndpoint: Endpoint {
    typealias Request = EmptyRequest

    typealias Response = Referral

    var baseURL: URL { OnitServer.baseURL }

    var path: String { "/v1/referral/code" }

    let uniqueCode: String

    var getParams: [String : String]? {
        ["uniqueCode": uniqueCode]
    }

    var method: HTTPMethod { .get }

    var token: String? { nil }

    var requestBody: Request? { nil }

    var additionalHeaders: [String : String]? { nil }

    var timeout: TimeInterval? { nil }
}
