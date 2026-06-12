//
//  AzureBlobUploader.swift
//  Onit
//
//  Created by Kévin Naudin on 21/01/2026.
//

import Foundation

/// Configuration for Azure Blob Storage connection
struct AzureConfig: Sendable {
    let baseURL: String
    let container: String
    let sasKey: String

    var isConfigured: Bool {
        !baseURL.isEmpty && !container.isEmpty && !sasKey.isEmpty
    }
}

/// Error types for Azure Blob upload operations
enum AzureUploadError: Error {
    case missingConfiguration
    case invalidURL
    case uploadFailed(Error)
    case fileNotFound
}

/// Base actor for uploading files to Azure Blob Storage.
/// Provides common upload functionality for dataset collection.
actor AzureBlobUploader {

    // MARK: - Properties

    private let session: URLSession
    let config: AzureConfig
    private let logPrefix: String

    // MARK: - Initialization

    init(config: AzureConfig, logPrefix: String) {
        self.config = config
        self.logPrefix = logPrefix

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Public Methods

    /// Upload a file to Azure Blob Storage
    /// - Parameters:
    ///   - localURL: Local file URL to upload
    ///   - remotePath: Remote path in the container (e.g., "case_001/audio.wav")
    ///   - contentType: MIME type of the file
    func uploadFile(localURL: URL, remotePath: String, contentType: String) async throws {
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw AzureUploadError.fileNotFound
        }

        let encodedSasKey = config.sasKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.sasKey
        let urlString = "\(config.baseURL)/\(config.container)/\(remotePath)?\(encodedSasKey)"

        guard let url = URL(string: urlString) else {
            throw AzureUploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version")
        request.setValue(formattedDate, forHTTPHeaderField: "x-ms-date")

        do {
            let (_, response) = try await session.upload(for: request, fromFile: localURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw AzureUploadError.uploadFailed(NSError(domain: "HTTP", code: statusCode))
            }
        } catch let error as AzureUploadError {
            throw error
        } catch {
            throw AzureUploadError.uploadFailed(error)
        }
    }

    /// Upload metadata.json file from a case directory
    /// - Parameters:
    ///   - caseDirectory: Local directory containing metadata.json
    ///   - remotePath: Remote base path for the case
    func uploadMetadata(from caseDirectory: URL, remotePath: String) async throws {
        let metadataURL = caseDirectory.appendingPathComponent("metadata.json")
        try await uploadFile(
            localURL: metadataURL,
            remotePath: "\(remotePath)/metadata.json",
            contentType: "application/json"
        )
    }

    // MARK: - Private Methods

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
