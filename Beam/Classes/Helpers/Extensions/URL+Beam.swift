//
//  URL+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation

extension URL {
    var minimizedHost: String {
        guard let host = self.host else { return "" }
        return host.split(separator: ".").suffix(2).joined(separator: ".")
    }

    var isSearchResult: Bool {
        if let host = host {
            return host.hasSuffix("google.com") && (path == "/url" || path == "/search")
        }

        return false
    }
}
