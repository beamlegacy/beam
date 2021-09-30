import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable, Equatable {

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
}

class Autocompleter: ObservableObject {

    private(set) var searchEngine: SearchEngine
    private var lastDataTask: URLSessionDataTask?

    init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
    }

    public func complete(query: String) -> Future<[AutocompleteResult], Never> {
        Future { promise in
            self.searchEngine.query = query
            guard query.count > 0,
                  let url = URL(string: self.searchEngine.autocompleteUrl) else {
                promise(.success([]))
                return
            }

            self.lastDataTask?.cancel()
            let description = self.searchEngine.description
            self.lastDataTask = BeamURLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }
                guard let data = data else {
                    promise(.success([]))
                    return
                }

                // Unfortunately Google sends suggestions results with charset ISO-8859-1
                // We can't serialize them easily so we need to convert it in ISO Latin first then reconverting in data UTF8
                let dataIntoISOString = String(data: data, encoding: .isoLatin1)
                guard let dataUtf8 = dataIntoISOString?.data(using: .utf8) else {
                    promise(.success([]))
                    return
                }

                let obj = try? JSONSerialization.jsonObject(with: dataUtf8)
                var res = [AutocompleteResult]()
                if let array = obj as? [Any], let r = array[1] as? [String] {
                    for (index, str) in r.enumerated() {
                        let isURL = str.mayBeWebURL
                        let source: AutocompleteResult.Source = isURL ? .url : .autocomplete
                        let url = isURL ? URL(string: str) : nil
                        var text = str
                        let info = index == 0 && url == nil ? description : nil
                        if let url = url {
                            text = url.urlStringWithoutScheme
                        }
                        res.append(AutocompleteResult(text: text,
                                                      source: source,
                                                      url: url, information: info,
                                                      completingText: query))
                    }
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
