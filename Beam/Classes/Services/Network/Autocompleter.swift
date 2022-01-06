import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable, Equatable, Comparable, CustomStringConvertible {

    enum Source: Equatable, Hashable {
        case history
        case note(noteId: UUID? = nil, elementId: UUID? = nil)
        case autocomplete
        case url
        case createCard
        case topDomain

        var iconName: String {
            switch self {
            case .history:
                return "field-history"
            case .autocomplete:
                return "field-search"
            case .createCard:
                return "field-card_new"
            case .note:
                return "field-card"
            case .topDomain, .url:
                return "field-web"
            }
        }
        static var note: Source {
            return Source.note(noteId: nil, elementId: nil)
        }
    }

    var id: String {
        "\(uuid)\(completingText ?? "")"
    }
    var text: String
    var source: Source
    var disabled: Bool = false
    var url: URL?
    var information: String?
    var completingText: String?
    var uuid = UUID()
    var score: Float?

    static func < (lhs: AutocompleteResult, rhs: AutocompleteResult) -> Bool {
        if let slhs = lhs.score, let srhs = rhs.score { return slhs < srhs }
        if lhs.score != nil { return false }
        if rhs.score != nil { return true }
        let lhsr = lhs.text.lowercased().commonPrefix(with: lhs.completingText?.lowercased() ?? "").count
        let rhsr = rhs.text.lowercased().commonPrefix(with: rhs.completingText?.lowercased() ?? "").count
        if lhsr == rhsr { return lhs.text < rhs.text }
        return lhsr < rhsr

    }
    var description: String {
        var urlToPrint: String
        if let url = url {
            urlToPrint = "\(url.host ?? "")\(url.path)"
        } else {
            urlToPrint = "<???>"
        }
        return "id: \(id) text: \(text) - source: \(source) - url: \(urlToPrint) - score: \(score ?? Float.nan)"
    }
}

class Autocompleter: ObservableObject {

    private(set) var searchEngine: SearchEngineDescription

    private var lastDataTask: URLSessionDataTask?

    init(searchEngine: SearchEngineDescription) {
        self.searchEngine = searchEngine
    }

    public func complete(query: String) -> Future<[AutocompleteResult], Never> {
        Future { promise in
            guard !query.isEmpty,
                  let url = self.searchEngine.suggestionsURL(forQuery: query)
            else {
                promise(.success([]))
                return
            }

            self.lastDataTask?.cancel()
            let description = self.searchEngine.description
            self.lastDataTask = BeamURLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }

                var res = [AutocompleteResult]()
                if query.containsCharacters {
                    res.append(AutocompleteResult(text: query, source: .autocomplete, url: url, information: description))
                }
                guard let data = data else {
                    promise(.success(res))
                    return
                }

                res = []

                for (index, str) in self.searchEngine.suggestions(from: data).enumerated() {
                    let isURL = str.mayBeWebURL
                    let source: AutocompleteResult.Source = isURL ? .url : .autocomplete
                    let url = isURL ? URL(string: str) : nil
                    var text = str
                    let info = (index == 0 && url == nil) ? description : nil
                    if let url = url {
                        text = url.urlStringWithoutScheme
                    }
                    let result = AutocompleteResult(
                        text: text,
                        source: source,
                        url: url,
                        information: info,
                        completingText: query
                    )
                    res.append(result)
                }
                promise(.success(res))
            }
            self.lastDataTask?.resume()
        }
    }

    public func clear() {
        lastDataTask?.cancel()
    }
}
