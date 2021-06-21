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

    var embed: URL? {
        guard let scheme = self.scheme,
              let host = self.host else {
            return nil
        }

        if let youtubeID = self.query?.capturedGroups(withRegex: "v=([\\w|\\d]+)&?.*").first {
            return URL(string: "\(scheme)://\(host)/embed/\(youtubeID)")
        }

        if self.path.contains("/embed/") {
            return self
        }

        return nil
    }

    var tld: String? {
        return host?.tld
    }

}
