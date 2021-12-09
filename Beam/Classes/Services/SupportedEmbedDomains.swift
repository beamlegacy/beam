//
//  SupportedEmbedDomains.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation
import BeamCore

class SupportedEmbedDomains {
    static var shared = SupportedEmbedDomains()

    private static let supportedEmbedDomainsDictKey_dict = "supportedEmbedDomains_dict"
    @UserDefault(key: supportedEmbedDomainsDictKey_dict, defaultValue: [:], suiteName: BeamUserDefaults.supportedEmbedDomains.suiteName)
    var providers: [String: String]

    private static let supportedEmbedDomainsDictKey_pattern = "supportedEmbedDomains_pattern"
    @UserDefault(key: supportedEmbedDomainsDictKey_pattern, defaultValue: "", suiteName: BeamUserDefaults.supportedEmbedDomains.suiteName)
    var pattern: String

    private static let supportedEmbedDomainsDictKey_date = "supportedEmbedDomains_lastUpdate"
    @UserDefault(key: supportedEmbedDomainsDictKey_date, defaultValue: nil, suiteName: BeamUserDefaults.supportedEmbedDomains.suiteName)
    var lastUpdate: Date?

    init () { updateDomainsSupportedByAPI() }

    func updateDomainsSupportedByAPI() {
        // Only query the API if the dictionary is empty or if the last update was more than a day ago
        guard moreThanADayAgo(date: lastUpdate) || providers.isEmpty else { return }

        RestAPIServer().request(serverRequest: RestAPIServer.Request.providers) { (result: Result<EmbedProvidersAPIResult, Error>) in
            switch result {
                // swiftlint:disable:next empty_enum_arguments
            case .failure(let error):
                Logger.shared.logDebug("Failed to update supported Embed API domains: \(error.localizedDescription)", category: .embed)
            case .success(let successResult):
                self.providers = successResult.providers
                self.pattern = successResult.pattern.replacingOccurrences(of: "\\\\", with: "\\")
                self.lastUpdate = BeamDate.now
            }
        }
    }

    private func moreThanADayAgo(date: Date?) -> Bool {
        guard let lastUpdate = date else { return false }
        let minute: Double = 60.0
        let hour: Double = 60.0 * minute
        let day: Double = 24 * hour

        return DateInterval(start: lastUpdate, end: BeamDate.now) > DateInterval(start: BeamDate.now, duration: day)
    }

    enum EmbedContentAPIStrategyError: Error {
        case parsingCachedItem
    }

    private struct EmbedProvidersAPIResult: Codable {
        var pattern: String
        var providers: [String: String]
    }
}
