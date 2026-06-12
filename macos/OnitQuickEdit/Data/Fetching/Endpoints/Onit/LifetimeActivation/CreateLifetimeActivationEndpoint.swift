//
//  CreateLifetimeActivationEndpoint.swift
//  Onit
//
//  Created by Loyd Kim on 4/8/26.
//

import Foundation

extension FetchingClient {
    func createLifetimeActivation(productName: ReferralProductName) async throws -> LifetimeActivation {
        let endpoint = CreateLifetimeActivationEndpoint(productName: productName)
        return try await execute(endpoint)
    }
}

struct CreateLifetimeActivationEndpoint: Endpoint {
    typealias Request = CreateLifetimeActivationRequest

    typealias Response = LifetimeActivation

    var baseURL: URL { OnitServer.baseURL }

    var path: String { "/v1/lifetime-activation" }

    var getParams: [String: String]? { nil }

    var method: HTTPMethod { .post }

    var token: String? { TokenManager.token }

    var requestBody: Request? { CreateLifetimeActivationRequest(productName: productName) }

    var additionalHeaders: [String: String]? { nil }

    var timeout: TimeInterval? { nil }

    let productName: ReferralProductName
}

struct CreateLifetimeActivationRequest: Encodable {
    let productName: ReferralProductName
}
