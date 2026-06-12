//
//  TokenValidationManager.swift
//  Onit
//
//  Created by Kévin Naudin on 02/04/2025.
//

import Defaults
import Foundation

@MainActor
class TokenValidationManager {

    static func getTokenForModel(_ model: AIModel?) -> String? {
        if let provider = model?.provider {
            switch provider {
            case .openAI:
                return Defaults[.isOpenAITokenValidated] ? Defaults[.openAIToken] : nil
            case .anthropic:
                return Defaults[.isAnthropicTokenValidated] ? Defaults[.anthropicToken] : nil
            case .xAI:
                return Defaults[.isXAITokenValidated] ? Defaults[.xAIToken] : nil
            case .googleAI:
                return Defaults[.isGoogleAITokenValidated] ? Defaults[.googleAIToken] : nil
            case .deepSeek:
                return Defaults[.isDeepSeekTokenValidated] ? Defaults[.deepSeekToken] : nil
            case .perplexity:
                return Defaults[.isPerplexityTokenValidated] ? Defaults[.perplexityToken] : nil
            case .cerebras:
                return Defaults[.isCerebrasTokenValidated] ? Defaults[.cerebrasToken] : nil
            case .custom:
                if let customProviderName = model?.customProviderName,
                   let customProvider = Defaults[.availableCustomProviders].first(where: { $0.name == customProviderName }),
                   customProvider.isTokenValidated {
                    return customProvider.token
                }
                return nil
            }
        }
        return nil
    }
}
