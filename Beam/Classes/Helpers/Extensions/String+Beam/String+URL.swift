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

    var urlString: URL? {
        guard maybeURL else { return nil }
        guard let url = URL(string: self) ?? URL(string: "https://" + self) else { return nil }
        return url
    }
}
