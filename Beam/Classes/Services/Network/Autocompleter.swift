import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable, Equatable {

    enum Source {
        case history
        case note
        case autocomplete
        case url
        case createCard
        case topDomain

        var iconName: String {
            switch self {
            case .history:
                return "field-history"
            case .autocomplete, .url:
                return "field-search"
            case .createCard:
                return "field-card_new"
            case .note:
                return "field-card"
            case .topDomain:
                return "field-top-domain"
            }
        }
    }

    var id: String {
        "\(uuid)\(completingText ?? "")"
    }
    var text: String
    var source: Source
    var url: URL?
    var information: String?
    var completingText: String?
    var uuid = UUID()
}

class Autocompleter: ObservableObject {

    @Published var results: [AutocompleteResult] = []

    static let autocompleteResultDescription = "Google Search"
    private var searchEngine: SearchEngine
    private var lastDataTask: URLSessionDataTask?

    init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
    }

    public func complete(query: String) {
        guard query.count > 0 else {
            self.results = []
            return
        }

        searchEngine.query = query
        guard let url = URL(string: searchEngine.autocompleteUrl) else {
            return
        }
        lastDataTask?.cancel()
        lastDataTask = BeamURLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data else { return }

            let obj = try? JSONSerialization.jsonObject(with: data)

            if let array = obj as? [Any], let r = array[1] as? [String] {
                var res = [AutocompleteResult]()
                for (index, str) in r.enumerated() {
                    let isURL = str.mayBeWebURL
                    let source: AutocompleteResult.Source = isURL ? .url : .autocomplete
                    let url = isURL ? URL(string: str) : nil
                    var text = str
                    let info = index == 0 ? Self.autocompleteResultDescription : nil
                    if let url = url {
                        text = url.urlStringWithoutScheme
                    }
                    res.append(AutocompleteResult(text: text,
                                                  source: source,
                                                  url: url, information: info,
                                                  completingText: query))
                }
                self.results = res
            }
        }
        lastDataTask?.resume()
    }

    public func clear() {
        lastDataTask?.cancel()
    }
}
