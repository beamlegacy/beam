import Foundation

public extension URL {

    private func removeWWWPrefix(in urlString: String) -> String {
        if urlString.hasPrefix("www.") {
            return String(urlString.dropFirst("www.".count))
        }
        return urlString
    }

    /// Returns `"business.app.beamapp.co"` from `"https://business.app.beamapp.co"`
    var minimizedHost: String? {
        guard let host = host else { return nil }
        return removeWWWPrefix(in: host)
    }

    /// Returns `"beamapp.co"` from `"https://business.app.beamapp.co"`
    var mainHost: String? {
        guard let minimizedHost = minimizedHost else { return nil }
        let components = minimizedHost.split(separator: ".")
        guard components.count > 2 else { return minimizedHost }
        return components.suffix(from: components.count - 2).joined(separator: ".")
    }

    var urlStringWithoutScheme: String {
        guard let scheme = scheme else { return absoluteString }
        let result = absoluteString.replacingOccurrences(of: "\(scheme)://", with: "")
        return removeWWWPrefix(in: result)
    }

    var urlWithScheme: URL {
        if scheme != "localhost" && scheme != nil {
            return self
        }
        return URL(string: "http://\(absoluteString)") ?? self
    }

    static var browserSchemes: [String?] {
        ["http", "https", "file"]
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
        var str = self.urlStringWithoutScheme
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

    var isDomain: Bool {
        self.pathComponents.count <= 1
    }
    var domain: URL? {
        guard let host = self.host,
              let scheme = self.scheme
        else {
            return nil
        }
        var urlString = "\(scheme)://\(host)/"
        if let port = self.port {
            urlString = "\(scheme)://\(host):\(port)/"
        }
        return URL(string: urlString)
    }

    /// Returns a string containing only the scheme and host.
    /// ```
    /// URL("https://business.app.beamapp.co/blah/blah")!.schemeAndHost
    /// // → "https://business.app.beamapp.co"
    /// ```
    var schemeAndHost: String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let rangeOfScheme = components.rangeOfScheme,
              let rangeOfHost = components.rangeOfHost
        else {
            return nil
        }

        let range = rangeOfScheme.lowerBound..<rangeOfHost.upperBound
        return String(absoluteString[range])
    }

    /// Removes the path component entirely if it is just a forward slash.
    /// ```
    /// URL(string: "https://business.app.beamapp.co/")!.rootPathRemoved
    /// // → "https://business.app.beamapp.co"
    ///
    /// URL(string: "https://business.app.beamapp.co/blah/blah/")!.rootPathRemoved
    /// // → "https://business.app.beamapp.co/blah/blah/" (no change)
    /// ```
    var rootPathRemoved: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        if components.path == "/" {
            components.path = ""
        }
        return components.url ?? self
    }

    func isSameOrigin(as url: URL) -> Bool {
        guard self.scheme == url.scheme, self.host == url.host, self.port == url.port else { return false }
        return true
    }

    var withRootPath: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        if components.path == "" {
            components.path = "/"
        }
        return components.url ?? self
    }

    // TODO: Implement all semantic preserving transformation listed here:
    // https://en.wikipedia.org/wiki/URI_normalization
    var normalized: URL {
        withRootPath
    }

    func replacingScheme(with other: String) -> Self {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        urlComponents.scheme = other
        return urlComponents.url ?? self
    }

    /// url with query, fragment removed and path truncated to optional first component
    var domainPath0: URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.query = nil
        components.fragment = nil
        let pathParts = components.path.split(separator: "/")
        components.path = pathParts.count == 0 ? "/" : "/\(pathParts[0])"
        return components.url
    }

    var isSearchEngineResultPage: Bool {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let host = components.host,
              let query = components.query else { return false }
        let path = components.path
        if host.contains("google"), path == "/search" { return true }
        if host.contains("bing"), path == "/search" { return true }
        if host.contains("ecosia"), path == "/search" { return true }
        if host.contains("duckduckgo"), path == "/", query.starts(with: "q=") { return true }
        return false
    }
    var fragmentRemoved: URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.fragment = nil
        return components.url
    }
    func shortString(maxLength: Int = 20) -> String {
        let candidate = urlStringWithoutScheme
        if candidate.count <= maxLength { return candidate }
        let chunkLength: Int = (maxLength / 2) - 1
        return candidate.prefix(chunkLength) + ".." + candidate.suffix(chunkLength)
    }
}
