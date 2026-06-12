//
//  SecretsManager.swift
//  Onit
//
//  Created by Kévin Naudin on 10/10/2025.
//

import Foundation

/// Manages access to application secrets.
///
/// All secrets are read from environment variables at runtime — never bundled.
///
/// The Azure key must be set with launchctl (required by GUI apps):
///
///     launchctl setenv AZURE_NON_AX_TRIGGER_SAS_KEY "..."
///
/// See macos/com.synth.environment.plist.sample for a LaunchAgent that sets
/// it automatically on login (recommended for team development).
enum SecretsManager {

    // MARK: - Secret Keys

    private enum SecretKey: String {
        case azureNonAXTriggerSasKey = "AZURE_NON_AX_TRIGGER_SAS_KEY"
    }

    // MARK: - Azure Blob Storage

    /// Retrieves the Azure Blob Storage base URL.
    static func getAzureBlobBaseUrl() -> String? {
        return "https://syntheticco.blob.core.windows.net"
    }

    /// Retrieves the Azure non-AX trigger container name.
    static func getAzureNonAXTriggerContainer() -> String? {
        return "non-ax-trigger"
    }

    /// Retrieves the Azure non-AX trigger SAS key from environment.
    static func getAzureNonAXTriggerSasKey() -> String? {
        return getFromEnvironment(.azureNonAXTriggerSasKey)
    }

    // MARK: - Private

    /// Reads a secret from process environment variables (plain text, not Base64).
    private static func getFromEnvironment(_ key: SecretKey) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key.rawValue],
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
