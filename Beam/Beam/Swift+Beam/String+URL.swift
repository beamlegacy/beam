//
//  String+URL.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation

extension String {
    var markdownizedURL: String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "()").inverted)
    }
}

extension URL {
    var minimizedHost: String {
        guard let host = self.host else { return "" }
        return host.split(separator: ".").suffix(2).joined(separator: ".")
    }
}
