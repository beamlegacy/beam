import Foundation

protocol SearchEngine {
    var name: String { get }
    var description: String { get }
    var query: String { get set }
    var formattedQuery: String { get }
    var searchUrl: String { get }
    var autocompleteUrl: String { get }
    func canHandle(_ queryUrl: URL) -> Bool
}

extension SearchEngine {
    var formattedQuery: String {
        query.addingPercentEncoding(withAllowedCharacters: .urlSearchQueryAllowed) ?? query
    }
}

class GoogleSearch: SearchEngine {
    let name: String = "Google"
    let description: String = "Google Search"
    var query: String = ""
    let prefix: String = "https://www.google.com/search?q="
    var searchUrl: String {
        "\(prefix)\(formattedQuery)&client=safari"
    }
    var autocompleteUrl: String {
        "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(formattedQuery)"
    }

    func canHandle(_ queryUrl: URL) -> Bool {
        if let host = queryUrl.host {
            return host.hasSuffix("google.com") && (queryUrl.path == "/url" || queryUrl.path == "/search")
        }
        return false
    }
}

class BingSearch: SearchEngine {
    let name: String = "Bing"
    let description: String = "Bing Search"
    var query: String = ""
    let prefix: String = "https://www.bing.com/search?q="
    var searchUrl: String {
        "\(prefix)\(formattedQuery)&qs=ds&form=QBLH"
    }
    var autocompleteUrl: String {
        "https://api.cognitive.microsoft.com/bing/v7.0/Suggestions?q=\(formattedQuery)"
    }

    func canHandle(_ queryUrl: URL) -> Bool {
        queryUrl.absoluteString.starts(with: prefix)
    }
}

class DuckDuckGoSearch: SearchEngine {
    let name: String = "Duck Duck Go"
    let description: String = "Duck Duck Search"
    var query: String = ""
    let prefix: String = "https://duckduckgo.com/?q="
    var searchUrl: String {
        "\(prefix)\(formattedQuery)&kp=-1&kl=us-en"
    }
    var autocompleteUrl: String {
        "https://api.duckduckgo.com/?format=json&q=\(formattedQuery)"
    }

    func canHandle(_ queryUrl: URL) -> Bool {
        queryUrl.absoluteString.starts(with: prefix)
    }
}

class MockSearchEngine: SearchEngine {
    let name: String = "Mock"
    let description: String = "Mock Search"
    var query: String = ""
    let prefix: String = "no"
    var searchUrl: String = ""
    var autocompleteUrl: String = ""

    func canHandle(_ queryUrl: URL) -> Bool {
        return false
    }
}

class SearchEngines {

    static let google: GoogleSearch = GoogleSearch()
    static let bing: BingSearch = BingSearch()
    static let duckDuckGo: DuckDuckGoSearch = DuckDuckGoSearch()

    static let supported: [SearchEngine] = [google, bing, duckDuckGo]

    static func get(_ queryUrl: URL) -> SearchEngine? {
        supported.first(where: { $0.canHandle(queryUrl) })
    }
}

private extension CharacterSet {

    static var urlSearchQueryAllowed: CharacterSet {
        var allowedQueryParamAndKey = CharacterSet.urlQueryAllowed
        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
        return allowedQueryParamAndKey
    }
}
