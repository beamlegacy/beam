//
//  GCSObjectManager.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation

class GCSObjectManager {
    private var auth: GCPAuthenticationManager
    private var bucketName: String

    init(bucket: String) throws {
        bucketName = bucket
        auth = try GCPAuthenticationManager()
    }

    public func uploadFile(filename: String, path: URL) async throws -> GCSUploadPayload {
        guard auth.isEnabled else {
            throw GCSObjectManagerErrors.disabledService
        }

        if auth.isAuthenticationRequired() {
            try await auth.createAccessToken(scope: "https://www.googleapis.com/auth/devstorage.read_write")
        }

        guard let url = URL(string: "https://storage.googleapis.com/upload/storage/v1/b/\(self.bucketName)/o?uploadType=media&name=" + filename) else {
            throw GCPCommonErrors.urlCreationError(description: "Impossible to create an URL from bucket address.")
        }
        var req = auth.getAuthenticatedRequest(url: url)

        req.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        req.httpMethod = "POST"
        req.httpBody = try String(contentsOf: path).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let response = response as? HTTPURLResponse else {
            throw GCPCommonErrors.castError(description: "Impossible to cast an URLResponse")
        }

        if response.statusCode > 299 {
            var decodedData: GCSUploadError = GCSUploadError()

            do {
                decodedData = try JSONDecoder().decode(GCSUploadError.self, from: data)
            } catch {
                throw GCPCommonErrors.jsonDecodeError(description: "Impossible to decode the upload error payload JSON.")
            }

            throw GCSObjectManagerErrors.uploadError(description: decodedData.description)
        }

        do {
            let decodedData = try JSONDecoder().decode(GCSUploadPayload.self, from: data)
            return decodedData
        } catch {
            throw GCPCommonErrors.jsonDecodeError(description: "Impossible to decode the upload payload JSON.")
        }
    }
}
