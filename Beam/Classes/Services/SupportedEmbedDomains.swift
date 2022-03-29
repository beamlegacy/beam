import Foundation
import Combine
import BeamCore

class SupportedEmbedDomains {
    static var shared = SupportedEmbedDomains()

    private(set) var providers: [String: String] = [:]
    /// Pattern with the right character escaping for Swift
    private(set) var nativePattern: String = initialPattern
    /// Pattern with the right character escaping for JavaScript
    private(set) var javaScriptPattern: String = initialJavaScriptPattern

    private var providersRequestFuture: Future<EmbedProvidersAPIResult, Error>?
    private var lastUpdate: Date?
    private var cancellables = Set<AnyCancellable>()

    init () { updateDomainsSupportedByAPI() }

    func updateDomainsSupportedByAPI() {
        cancellables = []

        providersPublisher()
            .sink { completion in
                if case let .failure(error) = completion {
                    Logger.shared.logDebug(
                        "Failed to update supported Embed API domains: \(error.localizedDescription)",
                        category: .embed
                    )
                }
            } receiveValue: { [weak self] result in
                self?.providers = result.providers
                self?.javaScriptPattern = result.pattern
                self?.nativePattern = result.pattern.replacingOccurrences(of: "\\\\", with: "\\")
                self?.lastUpdate = BeamDate.now
            }
            .store(in: &cancellables)
    }

    /// Returns a publisher that eventually resolves with the embed provider for a URL.
    func provider(for url: URL) -> AnyPublisher<EmbedProvider, Error> {
        let range = NSRange(location: 0, length: url.absoluteString.count)

        return providersPublisher()
            .tryMap { [url] result -> EmbedProvider in
                let provider = result.providers
                    .first { _, pattern in
                        guard let regexp = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                            return false
                        }
                        let matches = regexp.numberOfMatches(in: url.absoluteString, options: [], range: range)
                        return matches != 0
                    }
                    .map { EmbedProvider(rawValue: $0.key) ?? EmbedProvider.unknown }

                if let provider = provider {
                    return provider
                } else {
                    throw EmbedProviderError.unknownProvider
                }
            }
            .eraseToAnyPublisher()
    }

    /// Returns a publisher that eventually resolves with the API response when received, or resolves immediately
    /// if a response has been previously received.
    private func providersPublisher() -> AnyPublisher<EmbedProvidersAPIResult, Error> {
        // Only query the API if the last update was more than a day ago.
        // The dictonary gets cleared when Beam is restarted.
        if let lastUpdate = lastUpdate, moreThanADayAgo(since: lastUpdate) {
            // Clear cached API result
            providersRequestFuture = nil
        }

        if let future = providersRequestFuture {
            return future.eraseToAnyPublisher()
        }

        let future = Future<EmbedProvidersAPIResult, Error> { promise in
            RestAPIServer().request(serverRequest: RestAPIServer.Request.providers) { (result: Result<EmbedProvidersAPIResult, Error>) in
                switch result {
                case let .failure(error): promise(.failure(error))
                case let .success(result): promise(.success(result))
                }
            }
        }

        providersRequestFuture = future
        return future.eraseToAnyPublisher()
    }

    private func moreThanADayAgo(since date: Date) -> Bool {
        let minute: Double = 60.0
        let hour: Double = 60.0 * minute
        let day: Double = 24 * hour

        return DateInterval(start: date, end: BeamDate.now) > DateInterval(start: BeamDate.now, duration: day)
    }

    // MARK: -

    enum EmbedContentAPIStrategyError: Error {
        case parsingCachedItem
    }

    enum EmbedProviderError: Error {
        case unknownProvider
    }

    private struct EmbedProvidersAPIResult: Codable {
        var pattern: String
        var providers: [String: String]
    }

}

extension SupportedEmbedDomains {

    /// Default pattern until we fetch the real one from the api.
    private static let initialPattern = SupportedEmbedDomains.initialJavaScriptPattern.replacingOccurrences(of: "\\\\", with: "\\")

    private static let initialJavaScriptPattern = "(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:instagr\\\\.am|instagram\\\\.com)\\\\/p\\\\/([\\\\w-]+))|(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:flic\\\\.kr\\\\/p|flickr.com\\\\/photos)\\\\/[^\\\\s]+)|(?:https?:\\\\/\\\\/(?:www\\\\.)?deviantart\\\\.com\\\\/([a-z0-9_-]+)\\\\/art\\\\/([a-z0-9_-]+)+)|(?:https?:\\\\/\\\\/(?:www\\\\.)?twitch\\\\.tv\\\\/([a-z0-9_-]+)\\\\/video\\\\/([a-z0-9_-]+)+)|(?:https?:\\\\/\\\\/(?:www\\\\.)?soundcloud\\\\.com\\\\/([a-z0-9_-]+)\\\\/([a-z0-9_-]+))|(?:https?:\\\\/\\\\/(www|open|play)\\\\.?spotify\\\\.com\\\\/(artist|track|playlist|show)\\\\/([\\\\w\\\\-/]+))|(?:https?:\\\\/\\\\/(?:www\\\\.)?ted\\\\.com\\\\/talks\\\\/[\\\\w]+)|(?:https?:\\\\/\\\\/(?:www\\\\.)?vimeo\\\\.com\\\\/(?:(album)\\\\/(\\\\w+)\\\\/video\\\\/([0-9]+)|(groups)\\\\/(\\\\w+)\\\\/videos\\\\/([0-9]+)|(channels)\\\\/(\\\\w+)\\\\/([0-9]+)|(ondemand)\\\\/(\\\\w+)\\\\/([0-9]+)|(\\\\w+)))|(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:youtube\\\\.com\\\\/watch\\\\?v=|youtu\\\\.be\\\\/)([\\\\w-]+)(?:&(.*=.+))*)|(?:https?:\\\\/\\\\/(?:www\\\\.)?slideshare\\\\.net\\\\/([\\\\w\\\\-]+)\\\\/([\\\\w\\\\-]+))|(?:https?:\\\\/\\\\/(?:www\\\\.)?twitter\\\\.com\\\\/\\\\w+\\\\/status\\\\/[0-9]+(?:\\\\?s=[0-9]+)?)|(?:https?:\\\\/\\\\/(?:[\\\\w.-]+\\\\.)?figma.com\\\\/(?:file|proto)\\\\/([0-9a-zA-Z]{22,128})\\\\/(.*)?$)|(?:https:\\\\/\\\\/sketchfab.com\\\\/models\\\\/(\\\\w+))"
}
