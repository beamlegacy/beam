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
    }
    
    var id: UUID
    var string: String
    var source: Source
}

class Completer: ObservableObject {
    @Published var results: [AutoCompleteResult] = []
    
    public func complete(query: String) {
        let query = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        if let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(query)") {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                if let data = data {
                    do {
                        let obj = try JSONSerialization.jsonObject(with: data)
                        if let array = obj as? [Any] {
                            var res = [AutoCompleteResult]()
                            if let r = array[1] as? [String] {
                                for str in r {
                                    res.append(AutoCompleteResult(id: UUID(), string: str, source: .autoComplete))
                                }
                                self.results = res
                            }
                        }
                    } catch {
                        //                        print("AutoComplete call error")
                    }
                    
                }
            }.resume()
        }
    }
}
