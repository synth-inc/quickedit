//
//  GetLifetimeActivationStatsEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 4/8/26.
//

import Foundation

extension FetchingClient {
    func getLifetimeActivationStats(productName: ReferralProductName) async throws -> LifetimeActivationStats {
        let endpoint = GetLifetimeActivationStatsEndpoint(productName: productName)
        return try await execute(endpoint)
    }
}

struct GetLifetimeActivationStatsEndpoint: Endpoint {
    typealias Request = EmptyRequest

    typealias Response = LifetimeActivationStats

    var baseURL: URL { OnitServer.baseURL }

    var path: String { "/v1/lifetime-activation/stats" }

    let productName: ReferralProductName

    var getParams: [String : String]? {
        ["productName": productName.rawValue]
    }

    var method: HTTPMethod { .get }

    var token: String? { nil }

    var requestBody: Request? { nil }

    var additionalHeaders: [String : String]? { nil }

    var timeout: TimeInterval? { nil }
}
