//
//  AutoComplete.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation

struct AutoCompleteData: Codable {
    var query: String
    var results: [String]
}

public func autoComplete(query: String) -> [String] {
    var result: [String] = []
        if let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(query)") {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Autocomplete results: \(jsonString)")
                    }
                    do {
                        let res = try JSONDecoder().decode(AutoCompleteData.self, from: data)
                        print("res: \(res.results)")
                        result = res.results
                    } catch {
                        print("AutoComplete call error")
                    }
                    
                }
            }.resume()
        }
    return result
}
