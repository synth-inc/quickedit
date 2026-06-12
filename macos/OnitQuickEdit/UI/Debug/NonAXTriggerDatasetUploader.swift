//
//  NonAXTriggerDatasetUploader.swift
//  Onit
//
//  Created on 16/01/2026.
//

#if DEBUG || ONIT_BETA
import Foundation

/// Uploads non-AX trigger dataset cases to Azure Blob Storage for collection from beta testers.
actor NonAXTriggerDatasetUploader {

    // MARK: - Singleton

    static let shared = NonAXTriggerDatasetUploader()

    // MARK: - Private Properties

    private let uploader: AzureBlobUploader

    // MARK: - Initialization

    private init() {
        let config = AzureConfig(
            baseURL: SecretsManager.getAzureBlobBaseUrl() ?? "",
            container: SecretsManager.getAzureNonAXTriggerContainer() ?? "",
            sasKey: SecretsManager.getAzureNonAXTriggerSasKey() ?? ""
        )
        self.uploader = AzureBlobUploader(config: config, logPrefix: "NonAXTriggerDatasetUploader")
    }

    // MARK: - Public Methods

    /// Upload a non-AX trigger dataset case (images + metadata) to Azure
    /// - Parameters:
    ///   - caseDirectory: Local directory containing before.png, after.png, and metadata.json
    ///   - caseName: Name of the case (e.g., "case_001")
    func uploadCase(from caseDirectory: URL, caseName: String) async {
        let isConfigured = await uploader.config.isConfigured
        guard isConfigured else {
            log.debug("NonAXTriggerDatasetUploader: Azure not configured, skipping upload")
            return
        }

        let beforeURL = caseDirectory.appendingPathComponent("before.png")
        let afterURL = caseDirectory.appendingPathComponent("after.png")
        let remotePath = caseName

        // Upload all files in parallel
        async let beforeUpload: () = uploader.uploadFile(
            localURL: beforeURL,
            remotePath: "\(remotePath)/before.png",
            contentType: "image/png"
        )
        async let afterUpload: () = uploader.uploadFile(
            localURL: afterURL,
            remotePath: "\(remotePath)/after.png",
            contentType: "image/png"
        )
        async let metadataUpload: () = uploader.uploadMetadata(
            from: caseDirectory,
            remotePath: remotePath
        )

        do {
            _ = try await (beforeUpload, afterUpload, metadataUpload)
            log.info("NonAXTriggerDatasetUploader: Successfully uploaded case \(caseName)")
        } catch {
            log.error("NonAXTriggerDatasetUploader: Failed to upload case \(caseName): \(error)")
        }
    }
}

#endif
