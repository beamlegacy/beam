import Foundation

public extension URL {

    private func removeWWWPrefix(in urlString: String) -> String {
        if urlString.hasPrefix("www.") {
            return String(urlString.dropFirst("www.".count))
        }
        return urlString
    }

    var minimizedHost: String? {
        guard let host = host else { return nil }
        return removeWWWPrefix(in: host)
    }

    var urlStringWithoutScheme: String {
        guard let scheme = scheme else { return absoluteString }
        let result = absoluteString.replacingOccurrences(of: "\(scheme)://", with: "")
        return removeWWWPrefix(in: result)
    }

    var urlWithScheme: URL {
        if scheme != nil {
            return self
        }
        return URL(string: "https://\(absoluteString)") ?? self
    }

    static var browserSchemes: [String?] {
        ["http", "https", "file"]
    }

    func extractYouTubeId() -> String? {
        // TODO: remove this when we can rely on oembed for url conversion
        let url = absoluteString
        let typePattern = "(?:(?:\\.be\\/|embed\\/|v\\/|\\?v=|\\&v=|\\/videos\\/)|(?:[\\w+]+#\\w\\/\\w(?:\\/[\\w]+)?\\/\\w\\/))([\\w-_]+)"
        let regex = try? NSRegularExpression(pattern: typePattern, options: .caseInsensitive)
        return regex
            .flatMap { $0.firstMatch(in: url, range: NSRange(location: 0, length: url.count)) }
            .flatMap { Range($0.range(at: 1), in: url) }
            .map { String(url[$0]) }
    }

    var embed: URL? {
        // TODO: remove this when we can rely on oembed for url conversion
        if let youtubeID = extractYouTubeId() {
            return URL(string: "https://www.youtube.com/embed/\(youtubeID)")
        }

        if path.contains("/embed/") {
            return self
        }

        return nil
    }

    var isImageURL: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif"]
        return imageExtensions.contains(self.pathExtension)
    }

    var tld: String? {
        host?.tld
    }

    /// Cleans up the non necessary characters in a url string.
    ///
    /// Exemple: `https://wikipedia.org` and `wikipedia.org/` are pointing to the same page.
    /// This method could be improved with more unnecessary strings to remove, like `index.html` , etc.
    var urlStringByRemovingUnnecessaryCharacters: String {
        var str = self.urlStringWithoutScheme.lowercased()
        let last = str.last
        if ["/", "?"].contains(last) {
            str = String(str.dropLast())
        }
        return str
    }

    func domainMatchWith(_ text: String) -> Bool {
        let decomposedDomain = urlStringWithoutScheme.components(separatedBy: "/")
        let decomposedSearchString = text.components(separatedBy: "/")

        if decomposedDomain.count == 2 && decomposedSearchString.count == 1 {
            if decomposedDomain[1].isEmpty {
                if decomposedDomain[1].isEmpty && decomposedDomain[0].contains(decomposedSearchString[0]) && decomposedSearchString[0].count <= decomposedDomain[0].count {
                    return true
                }
            }
        } else if decomposedDomain.count == 1 {
            if decomposedDomain[0].contains(decomposedSearchString[0]) {
                return true
            }
        } else if decomposedDomain.count == decomposedSearchString.count {
            return decomposedDomain == decomposedSearchString
        }
        return false
    }
}
