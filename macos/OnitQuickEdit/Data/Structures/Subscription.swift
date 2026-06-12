//
//  Subscription.swift
//  Onit
//
//  Created by Jason Swanson on 4/29/25.
//

struct SubscriptionStatus {
    static let trialing = "⭐️ Pro 2-Week Trial"
    static let active = "⭐️ Pro"
    static let free = "Free Plan"

    /// Returns the localized display name for a given subscription status.
    @MainActor
    static func localizedName(_ status: String) -> String {
        return String.localized(status, table: "Settings")
    }
}

struct Subscription: Codable {
    let id: String
    let status: String
    let statusMessage: String?
    let trialEnd: Double? // Second since the epoch
    let currentPeriodStart: Double // Second since the epoch
    let currentPeriodEnd: Double // Second since the epoch
    let cancelAtPeriodEnd: Bool
}

struct ChatUsage: Codable {
    let usage: Double
    let quota: Double
    let paid: Bool
    let currentPeriodStart: Double // Second since the epoch
    let currentPeriodEnd: Double // Second since the epoch
}
