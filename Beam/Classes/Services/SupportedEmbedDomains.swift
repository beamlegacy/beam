import Foundation
import Combine

/// Domains whose links can be embedded in notes, using a built-in pattern.
class SupportedEmbedDomains {
    static var shared = SupportedEmbedDomains()

    /// Pattern with the right character escaping for Swift
    let nativePattern: String = initialPattern
    /// Pattern with the right character escaping for JavaScript
    let javaScriptPattern: String = initialJavaScriptPattern

    /// Returns a publisher resolving with the embed provider for a URL, matched on its host.
    func provider(for url: URL) -> AnyPublisher<EmbedProvider, Error> {
        guard let provider = Self.provider(forHost: url.host?.lowercased() ?? "") else {
            return Fail(error: EmbedProviderError.unknownProvider).eraseToAnyPublisher()
        }
        return Just(provider).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    private static let providerHosts: [(EmbedProvider, [String])] = [
        (.deviantArt, ["deviantart.com"]),
        (.figma, ["figma.com"]),
        (.flickr, ["flickr.com", "flic.kr"]),
        (.instagram, ["instagram.com", "instagr.am"]),
        (.sketchfab, ["sketchfab.com"]),
        (.slideshare, ["slideshare.net"]),
        (.soundCloud, ["soundcloud.com"]),
        (.spotify, ["spotify.com"]),
        (.ted, ["ted.com"]),
        (.twitch, ["twitch.tv"]),
        (.twitter, ["twitter.com", "x.com"]),
        (.vimeo, ["vimeo.com"]),
        (.youTube, ["youtube.com", "youtu.be"]),
        (.reddit, ["reddit.com"]),
        (.snapchat, ["snapchat.com"])
    ]

    private static func provider(forHost host: String) -> EmbedProvider? {
        providerHosts.first { _, domains in
            domains.contains { host == $0 || host.hasSuffix(".\($0)") }
        }?.0
    }

    enum EmbedProviderError: Error {
        case unknownProvider
    }
}

extension SupportedEmbedDomains {

    private static let initialPattern = SupportedEmbedDomains.initialJavaScriptPattern.replacingOccurrences(of: "\\\\", with: "\\")

    private static let initialJavaScriptPattern = "(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:instagr\\\\.am|instagram\\\\.com)\\\\/p\\\\/([\\\\w-]+)))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:flic\\\\.kr\\\\/p|flickr.com\\\\/photos)\\\\/[^\\\\s]+))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?deviantart\\\\.com\\\\/([a-z0-9_-]+)\\\\/art\\\\/([a-z0-9_-]+)+))|(?:(?:(?<url>https?:\\\\/\\\\/(?:www\\\\.)?twitch\\\\.tv\\\\/(?<channel>[a-z0-9_-]+)\\\\/video\\\\/(?<id>[a-z0-9_-]+)+))|(?:https:\\\\/\\\\/clips\\\\.twitch\\\\.tv\\\\/embed\\\\?clip=(?<cnt>https?:\\\\/\\\\/(?:www\\\\.)?twitch\\\\.tv\\\\/(?<iframechannel>[a-z0-9_-]+)\\\\/video\\\\/(?<iframeid>[a-z0-9_-]+)+)))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?soundcloud\\\\.com\\\\/([a-z0-9_-]+)\\\\/([a-z0-9_-]+))|(?:(?:(?:https%3A%2F%2F)|(?:https:\\\\/\\\\/))api.soundcloud.com.+))|(?:(?:https?:\\\\/\\\\/(www|open|play)\\\\.?spotify\\\\.com\\\\/(artist|track|playlist|show)\\\\/([\\\\w\\\\-/]+))|(?:https?:\\\\/\\\\/(www|open|play)\\\\.?spotify\\\\.com\\\\/embed\\\\/(artist|track|playlist|show)\\\\/([\\\\w\\\\-/]+)))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?ted\\\\.com\\\\/talks\\\\/[\\\\w]+)|(?:https?:\\\\/\\\\/(?:embed\\\\.)?ted\\\\.com\\\\/talks\\\\/[\\\\w]+))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?vimeo\\\\.com\\\\/(?:(?:album)\\\\/(?:\\\\w+)\\\\/video\\\\/(?:[0-9]+)|(?:groups)\\\\/(?:\\\\w+)\\\\/videos\\\\/(?:[0-9]+)|(?:channels)\\\\/(?:\\\\w+)\\\\/(?:[0-9]+)|(?:ondemand)\\\\/(?:\\\\w+)\\\\/(?:[0-9]+)|(?:\\\\w+)))|(?:https?:\\\\/\\\\/(?:player\\\\.)?vimeo.com\\\\/video\\\\/(?:\\\\w+)\\\\?h=(?:\\\\w+)\\\\&app_id=(?:[0-9]+)$))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:youtube\\\\.com\\\\/watch\\\\?v=|youtu\\\\.be\\\\/)([\\\\w-]+)(?:&(.*=.+))*)|(?:https?:\\\\/\\\\/(?:www\\\\.)?(?:youtube\\\\.com\\\\/embed\\\\/)(?<videoId>[\\\\w-]+)(?:&(.*=.+))*\\\\?feature=oembed))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?slideshare\\\\.net\\\\/(?<username>[\\\\w-]+)\\\\/(?<presentation>[\\\\w-]+)$)|(?:https?:\\\\/\\\\/(?:www\\\\.)?slideshare\\\\.net\\\\/slideshow\\\\/embed_code\\\\/key\\\\/([\\\\w-]+)))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?twitter\\\\.com\\\\/\\\\w+\\\\/status\\\\/[0-9]+(?:\\\\?s=[0-9]+)?)|(?:https?:\\\\/\\\\/(?:platform\\\\.)?twitter\\\\.com\\\\/embed\\\\/Tweet.html.+$))|(?:(?:https?:\\\\/\\\\/(?:[\\\\w.-]+\\\\.)?figma.com\\\\/(?:file|proto)\\\\/([0-9a-zA-Z]{22,128})\\\\/?(.*)?$)|(?:https:\\\\/\\\\/www\\\\.figma\\\\.com\\\\/embed\\\\?embed_host=beam&url=https?:\\\\/\\\\/(?:[\\\\w.-]+\\\\.)?figma.com\\\\/(?:file|proto)\\\\/([0-9a-zA-Z]{22,128})\\\\/(.*)?$))|(?:(?:https:\\\\/\\\\/sketchfab.com\\\\/models\\\\/(\\\\w+))|(?:https:\\\\/\\\\/sketchfab.com\\\\/models\\\\/(\\\\w+)\\\\/embed))|(?:(?:https?:\\\\/\\\\/([a-z0-9_-]+)?.?reddit\\\\.com\\\\/?(r|user)?\\\\/?([a-z0-9_-]+)?\\\\/?(comments)\\\\/?([a-z0-9_-]+)?\\\\/?([a-z0-9_-]+)?\\\\/?([a-z0-9_-]+)?))|(?:(?:https?:\\\\/\\\\/(?:www\\\\.)?google.*\\\\/maps\\\\/?(?:place)?\\\\/?(?<location>.+)?(?:\\\\/@(?<lat>.+),(?<lon>.+),(?<zoom>.+z))?($|\\\\/))|(?:https?:\\\\/\\\\/(?:(?:maps\\\\.)|(?:www\\\\.))?google.*\\\\/maps(?:(?:\\\\/?.+q=.+)|(?:\\\\/embed\\\\/v[0-1]\\\\/place\\\\?.+q=.+))))"
}
