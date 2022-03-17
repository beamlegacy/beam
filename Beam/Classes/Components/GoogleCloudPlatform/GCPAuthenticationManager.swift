//
//  GCPAuthenticationManager.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation
import CryptoKit
import BeamCore

class GCPAuthenticationManager {
    private var accessToken: String
    private var pkcs1PrivateKey: Data?
    private var createdAt: Int
    private(set) var isEnabled: Bool

    init() throws {
        accessToken = ""
        createdAt = 0

        // If at least one of the variables is not set, the feature is disabled.
        if EnvironmentVariables.GoogleCloudPlatform.Authentication.privateKey.starts(with: "$(") || EnvironmentVariables.GoogleCloudPlatform.Authentication.clientEmail.starts(with: "$(") || EnvironmentVariables.GoogleCloudPlatform.Authentication.tokenURI.starts(with: "$(") {
            Logger.shared.logWarning("GCP Authentication is disabled. Any GCP related task will be ignored.", category: .general)
            isEnabled = false
            return
        }
        isEnabled = true
    }

    private func createJWTToken(scope: String) throws -> String {
        let header = """
        {"alg": "RS256", "typ": "JWT"}
        """
        createdAt = Int(BeamDate.now.timeIntervalSince1970)
        let claim = """
        {"aud": "\(EnvironmentVariables.GoogleCloudPlatform.Authentication.tokenURI)", "exp": "\(Int(BeamDate.now.timeIntervalSince1970) + 3600)", "iat": \(createdAt), "iss": \(EnvironmentVariables.GoogleCloudPlatform.Authentication.clientEmail), "scope": "\(scope)"}
        """
        guard let headerData = header.data(using: .utf8) else {
            throw GCPCommonErrors.stringToDataError(description: "Issue to convert the JWT header String in data")
        }
        let headerBase64encoded = headerData.base64EncodedString()
        guard let claimData = claim.data(using: .utf8) else {
            throw GCPCommonErrors.stringToDataError(description: "Issue to convert the JWT claim String in data")
        }
        let claimBase64encoded = claimData.base64EncodedString()
        let jwtTokenBase64Encoded = [headerBase64encoded, claimBase64encoded].joined(separator: ".")

        return jwtTokenBase64Encoded.base64URLEscaped()
    }

    public func getAuthenticatedRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)

        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return req
    }

    private func signJWTToken(jwtToken: String) throws -> String {
        var error: Unmanaged<CFError>?
        guard let createdPkcs1PrivateKey = pkcs1PrivateKey as NSData?,
              let privateKey = SecKeyCreateWithData(createdPkcs1PrivateKey, [
                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate
        ] as NSDictionary, &error) else {
            throw GCPAuthenticationManagerErrors.privateKeyError(description: error.debugDescription)
        }
        guard let jwtTokenData = jwtToken.data(using: .utf8) else {
            throw GCPCommonErrors.stringToDataError(description: "Issue to convert the JWT Token String in data")
        }
        let jwtTokenHash = SHA256.hash(data: jwtTokenData)
        guard let signature = SecKeyCreateSignature(privateKey, SecKeyAlgorithm.rsaSignatureDigestPKCS1v15SHA256, (jwtTokenHash.data) as CFData, &error) as Data? else {
            throw GCPAuthenticationManagerErrors.signatureError(description: error.debugDescription)
        }

        return signature.base64EncodedString(options: []).base64URLEscaped()
    }

    public func isAuthenticationRequired() -> Bool {
        // Check only 59 minutes instead of 60 to be sure to do not get rejected if the time is near 3600 seconds
        return self.accessToken == "" || Int(BeamDate.now.timeIntervalSince1970) - self.createdAt >= 3540
    }

    public func createAccessToken(scope: String) async throws {
        try convertPkCS8PrivateKeyToPKCS1()

        let jwtTokenBase64Encoded = try createJWTToken(scope: scope)
        let signedJWTTokenBase64Encoded = try signJWTToken(jwtToken: jwtTokenBase64Encoded)
        let payload = [jwtTokenBase64Encoded, signedJWTTokenBase64Encoded].joined(separator: ".")

        try await fetchAccessToken(payload: payload)
    }

    private func convertPkCS8PrivateKeyToPKCS1() throws {
        guard pkcs1PrivateKey == nil else { return }
        let cleanedPrivateKeyBase64 = EnvironmentVariables.GoogleCloudPlatform.Authentication.privateKey
            .split(separator: "\n")
            .dropFirst()
            .dropLast()
            .joined()
        guard let decodedCleanedPrivateKey = Data(base64Encoded: cleanedPrivateKeyBase64, options: []) else {
            throw GCPCommonErrors.stringToDataError(description: "Issue to convert the cleaned private key String in data")
        }

        // If the 26th bit is 0x30 it means that the RSA private key is in PKCS#8 format. Otherwise the key is in PKCS#1 format.
        // The bits before the 26th position is a sequence that identifies the key algorithm (the header). As defined in RFC 5208 that has been obsoleted by RFC 5958.
        if decodedCleanedPrivateKey[26] == 0x30 {
            pkcs1PrivateKey = decodedCleanedPrivateKey.advanced(by: 26)

            return
        }

        pkcs1PrivateKey = decodedCleanedPrivateKey
    }

    private func fetchAccessToken(payload: String) async throws {
        guard let url = URL(string: EnvironmentVariables.GoogleCloudPlatform.Authentication.tokenURI) else {
            throw GCPCommonErrors.urlCreationError(description: "Impossible to create an URL from the token URI address.")
        }
        var req = URLRequest(url: url)
        let grant = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer"
        let assertion = "assertion=\(payload)"
        let combinedStr = [grant, assertion].joined(separator: "&")
        let reqdat = combinedStr.data(using: .utf8)

        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpMethod = "POST"
        req.httpBody = reqdat

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let response = response as? HTTPURLResponse else {
            throw GCPCommonErrors.castError(description: "Impossible to cast an URLResponse")
        }

        if response.statusCode > 299 {
            var decodedData = GCPOauth2Error()

            do {
                decodedData = try JSONDecoder().decode(GCPOauth2Error.self, from: data)
            } catch {
                throw GCPCommonErrors.jsonDecodeError(description: "Impossible to decode the authentication error payload JSON.")
            }

            throw GCPAuthenticationManagerErrors.authentError(description: decodedData.description)
        }

        do {
            let decodedData = try JSONDecoder().decode(GCPOauth2Payload.self, from: data)
            accessToken = decodedData.access_token
        } catch {
            throw GCPCommonErrors.jsonDecodeError(description: "Impossible to decode the authentication payload JSON.")
        }
    }
}
