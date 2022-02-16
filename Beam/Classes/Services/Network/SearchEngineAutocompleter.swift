//
//  SearchEngineAutocompleter.swift
//  Beam
//
//  Created by Remi Santos on 03/02/2022.
//

import Foundation
import Combine

class SearchEngineAutocompleter: ObservableObject {

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
            let engineDescription = self.searchEngine.description
            self.lastDataTask = BeamURLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { return }
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }

                var res = [AutocompleteResult]()
                if query.containsCharacters {
                    res.append(AutocompleteResult(text: query, source: .searchEngine, url: nil, information: engineDescription))
                }
                guard let data = data else {
                    promise(.success(res))
                    return
                }

                res = self.searchEngine.suggestions(from: data).map { str in
                    let isURL = str.mayBeWebURL
                    let source: AutocompleteResult.Source = isURL ? .url : .searchEngine
                    let url = isURL ? URL(string: str) : nil
                    var text = str
                    let info = isURL ? nil : engineDescription
                    if let url = url {
                        text = url.urlStringWithoutScheme
                    }
                    return AutocompleteResult(
                        text: text,
                        source: source,
                        url: url,
                        information: info,
                        completingText: query,
                        urlFields: []
                    )
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
