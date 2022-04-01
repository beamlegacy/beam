//
//  HostnameCanonicalizer.swift
//  Beam
//
//  Created by Beam on 28/03/2022.
//

import Foundation

/// The `shared-credentials.json` resource used in this class comes from Apple's Password Manager Resources repository:
/// https://github.com/apple/password-manager-resources
/// Available under MIT License.
final class HostnameCanonicalizer {
    private struct HostnameRules: Decodable {
        var canonical: [String]?
    }

    private struct CredentialsRules: Decodable {
        var shared: [String]?
        var from: [String]?
        var to: [String]?
        var fromDomainsAreObsoleted: Bool?
    }

    private var canonicalSuffixes: [String]
    private var sharedCredentialsSets: [Set<String>]
    private var allSharedCredentials: Set<String>

    static var shared = HostnameCanonicalizer()

    init() {
        let decoder = JSONDecoder()
        guard let hostnameRulesURL = Bundle.main.url(forResource: "canonical-hostnames", withExtension: "json"),
              let sharedCredentialsURL = Bundle.main.url(forResource: "shared-credentials", withExtension: "json")
        else {
            fatalError("Error while creating HostnameCanonicalizer URL")
        }
        do {
            let hostnameRulesData = try Data(contentsOf: hostnameRulesURL)
            let hostnameRules = try decoder.decode(HostnameRules.self, from: hostnameRulesData)
            canonicalSuffixes = (hostnameRules.canonical ?? []).map {
                $0.hasPrefix(".") ? $0 : "." + $0
            }
            let sharedCredentialsData = try Data(contentsOf: sharedCredentialsURL)
            let sharedCredentialsRules = try decoder.decode([CredentialsRules].self, from: sharedCredentialsData)
            let sharedCredentialsSets = sharedCredentialsRules.compactMap { rules -> Set<String>? in
                if let shared = rules.shared {
                    return Set(shared)
                }
                if let from = rules.from, let to = rules.to {
                    return Set(from + to)
                }
                return nil
            }
            self.sharedCredentialsSets = sharedCredentialsSets
            self.allSharedCredentials = sharedCredentialsSets.reduce(into: Set<String>()) {
                $0 = $0.union($1)
            }
        } catch {
            fatalError("Error while reading HostnameCanonicalizer file: \(error)")
        }
    }

    func canonicalHostname(for hostname: String) -> String? {
        guard let suffix = canonicalSuffixes.first(where: hostname.hasSuffix) else { return nil }
        return String(suffix.dropFirst())
    }

    func hostsSharingCredentials(with host: String) -> Set<String>? {
        guard allSharedCredentials.contains(host) else { return nil }
        return sharedCredentialsSets.first { $0.contains(host) }
    }
}
