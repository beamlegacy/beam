//
//  URL+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation

public extension URL {

    private func removeWWWPrefix(in urlString: String) -> String {
        if urlString.hasPrefix("www.") {
            return String(urlString.dropFirst("www.".count))
        }
        return urlString
    }

    var minimizedHost: String? {
        guard let host = self.host else { return nil }
        return removeWWWPrefix(in: host)
    }

    var urlStringWithoutScheme: String {
        guard  let scheme = self.scheme else { return self.absoluteString }
        let result = self.absoluteString.replacingOccurrences(of: "\(scheme)://", with: "")
        return removeWWWPrefix(in: result)
    }

    var urlWithScheme: URL {
        if self.scheme != nil {
            return self
        }
        return URL(string: "https://\(self.absoluteString)") ?? self
    }

    var isSearchResult: Bool {
        if let host = host {
            return host.hasSuffix("google.com") && (path == "/url" || path == "/search")
        }

        return false
    }

    static var urlSchemes: [String?] {
        return ["http", "https", "file"]
    }

    func extractYouTubeId() -> String? {
        // TODO: remove this when we can rely on oembed for url conversion
        let url = self.absoluteString
        let typePattern = "(?:(?:\\.be\\/|embed\\/|v\\/|\\?v=|\\&v=|\\/videos\\/)|(?:[\\w+]+#\\w\\/\\w(?:\\/[\\w]+)?\\/\\w\\/))([\\w-_]+)"
        let regex = try? NSRegularExpression(pattern: typePattern, options: .caseInsensitive)
        return regex
            .flatMap { $0.firstMatch(in: url, range: NSRange(location: 0, length: url.count)) }
            .flatMap { Range($0.range(at: 1), in: url) }
            .map { String(url[$0]) }
    }

    var embed: URL? {
        guard let scheme = self.scheme,
              let host = self.host else {
            return nil
        }

        // TODO: remove this when we can rely on oembed for url conversion
        if let youtubeID = self.extractYouTubeId() {
            return URL(string: "\(scheme)://\(host)/embed/\(youtubeID)")
        }

        if self.path.contains("/embed/") {
            return self
        }

        return nil
    }

    var isImage: Bool {
        let imageExtensions = ["png", "jpg", "jepg", "gif"]
        return imageExtensions.contains(self.pathExtension)
    }

    var tld: String? {
        return host?.tld
    }
}
