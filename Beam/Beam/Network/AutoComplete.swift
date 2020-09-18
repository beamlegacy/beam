//
//  AutoComplete.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation

public func autoComplete(query: String, complete: @escaping ([String]) -> Void) {
    if let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(query)") {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Autocomplete results: \(jsonString)")
                }
                do {
                    let obj = try JSONSerialization.jsonObject(with: data)
                    if let array = obj as? [Any] {
                        if let results = array[1] as? [String] {
//                            print("res: \(results)")
                            complete(results)
                        }
                    }
                } catch {
                    print("AutoComplete call error")
                }
                
            }
        }.resume()
    }
}
