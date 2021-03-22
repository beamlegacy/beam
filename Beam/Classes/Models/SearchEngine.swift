//
//  SearchEngine.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation

protocol SearchEngine {
    var query: String { get set }
    var formatedQuery: String { get }
    var searchUrl: String { get }
    var autocompleteUrl: String { get }
}

extension SearchEngine {
    var formatedQuery: String {
        var q = query
        q = q.replacingOccurrences(of: " ", with: "+")
        q = q.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        return q
    }
}

struct GoogleSearch: SearchEngine {
    var query: String = ""
    var searchUrl: String {
        return "https://www.google.com/search?q=\(formatedQuery)&client=safari"
    }
    var autocompleteUrl: String {
        return "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(formatedQuery)"
    }
}

struct BingSearch: SearchEngine {
    var query: String = ""
    var searchUrl: String {
        return "https://www.bing.com/search?q=\(formatedQuery)&qs=ds&form=QBLH"
    }
    var autocompleteUrl: String {
        return "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(formatedQuery)"
    }
}

struct DuckDuckGoSearch: SearchEngine {
    var query: String = ""
    var searchUrl: String {
        return "https://duckduckgo.com/?q=\(formatedQuery)&kp=-1&kl=us-en"
    }
    var autocompleteUrl: String {
        return "https://suggestqueries.google.com/complete/search?client=firefox&output=toolbar&q=\(formatedQuery)"
    }
}
