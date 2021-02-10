//
//  AutoComplete.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutoCompleteResult: Identifiable {
    enum Source {
        case history
        case note
        case autoComplete
        case createCard
    }

    var id: UUID
    var string: String
    var title: String?
    var source: Source
}

class Completer: ObservableObject {
    @Published var results: [AutoCompleteResult] = []

    public func complete(query: String) {
        guard query.count > 0 else {
            self.results = []
            return
        }

        guard let query = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(query)") else {
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data else { return }

            let obj = try? JSONSerialization.jsonObject(with: data)

            if let array = obj as? [Any], let r = array[1] as? [String] {
                var res = [AutoCompleteResult]()

                for str in r {
                    res.append(AutoCompleteResult(id: UUID(), string: str, source: .autoComplete))
                }
                self.results = res
            }
        }.resume()
    }
}
