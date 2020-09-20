//
//  AutoComplete.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import Combine

struct AutoCompleteResult: Identifiable {
    var id = UUID()
    var string: String
}

class Completer: ObservableObject {
    @Published var results: [AutoCompleteResult] = []
    
    public func complete(query: String) {
        let query = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        if let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(query)") {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                if let data = data {
                    do {
                        let obj = try JSONSerialization.jsonObject(with: data)
                        if let array = obj as? [Any] {
                            var res = [AutoCompleteResult]()
                            if let r = array[1] as? [String] {
                                for str in r {
                                    res.append(AutoCompleteResult(string: str))
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
