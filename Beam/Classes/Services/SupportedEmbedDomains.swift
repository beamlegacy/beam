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

    private(set) var providers: [String: String] = [:]

    private(set) var pattern: String = initialPattern

    private var lastUpdate: Date?

    init () { updateDomainsSupportedByAPI() }

    func updateDomainsSupportedByAPI() {
        // Only query the API if the dictionary is empty or if the last update was more than a day ago.
        // The dictonary gets cleared when Beam is restarted.
        guard providers.isEmpty || moreThanADayAgo(date: lastUpdate) else { return }

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

    enum EmbedContentAPIStrategyError: Error {
        case parsingCachedItem
    }

    private struct EmbedProvidersAPIResult: Codable {
        var pattern: String
        var providers: [String: String]
    }

    private func moreThanADayAgo(date: Date?) -> Bool {
        guard let lastUpdate = date else { return false }
        let minute: Double = 60.0
        let hour: Double = 60.0 * minute
        let day: Double = 24 * hour

        return DateInterval(start: lastUpdate, end: BeamDate.now) > DateInterval(start: BeamDate.now, duration: day)
    }
}

extension SupportedEmbedDomains {

    /// Default pattern until we fetch the real one from the api.
    private static let initialPattern = "(?:https?:\\/\\/(?:www\\.)?(?:instagr\\.am|instagram\\.com)\\/p\\/([\\w-]+))|(?:https?:\\/\\/(?:www\\.)?(?:flic\\.kr\\/p|flickr.com\\/photos)\\/[^\\s]+)|(?:https?:\\/\\/(?:www\\.)?deviantart\\.com\\/([a-z0-9_-]+)\\/art\\/([a-z0-9_-]+)+)|(?:https?:\\/\\/(?:www\\.)?twitch\\.tv\\/([a-z0-9_-]+)\\/video\\/([a-z0-9_-]+)+)|(?:https?:\\/\\/(?:www\\.)?soundcloud\\.com\\/([a-z0-9_-]+)\\/([a-z0-9_-]+))|(?:https?:\\/\\/(www|open|play)\\.?spotify\\.com\\/(artist|track|playlist|show)\\/([\\w\\-/]+))|(?:https?:\\/\\/(?:www\\.)?ted\\.com\\/talks\\/[\\w]+)|(?:https?:\\/\\/(?:www\\.)?vimeo\\.com\\/(?:(album)\\/(\\w+)\\/video\\/([0-9]+)|(groups)\\/(\\w+)\\/videos\\/([0-9]+)|(channels)\\/(\\w+)\\/([0-9]+)|(ondemand)\\/(\\w+)\\/([0-9]+)|(\\w+)))|(?:https?:\\/\\/(?:www\\.)?(?:youtube\\.com\\/watch\\?v=|youtu\\.be\\/)([\\w-]+)(?:&(.*=.+))*)|(?:https?:\\/\\/(?:www\\.)?slideshare\\.net\\/([\\w\\-]+)\\/([\\w\\-]+))|(?:https?:\\/\\/(?:www\\.)?twitter\\.com\\/\\w+\\/status\\/[0-9]+(?:\\?s=[0-9]+)?)|(?:https?:\\/\\/(?:[\\w.-]+\\.)?figma.com\\/(?:file|proto)\\/([0-9a-zA-Z]{22,128})\\/(.*)?$)|(?:https:\\/\\/sketchfab.com\\/models\\/(\\w+))"
}
