//
//  Autocomplete.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable {
    enum Source {
        case history
        case note
        case autocomplete
        case url
        case createCard
    }

    var id: String {
        return "\(uuid)\(completingText ?? "")"
    }
    var text: String
    var source: Source
    var url: URL?
    var information: String?
    var completingText: String?
    var uuid = UUID()
}

class Completer: ObservableObject {
    @Published var results: [AutocompleteResult] = []

    private var searchEngine = GoogleSearch()
    private var lastDataTask: URLSessionDataTask?

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
                for str in r {
                    let isURL = str.urlString != nil
                    let source: AutocompleteResult.Source = isURL ? .url : .autocomplete
                    let url = isURL ? URL(string: str) : nil
                    var text = str
                    if let url = url {
                        text = url.urlStringWithoutScheme
                    }
                    res.append(AutocompleteResult(text: text, source: source, url: url, completingText: query))
                }
                self.results = res
            }
        }
        lastDataTask?.resume()
    }
}
