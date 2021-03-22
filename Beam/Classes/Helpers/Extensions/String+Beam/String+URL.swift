//
//  String+URL.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation

public extension String {
    var markdownizedURL: String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "()").inverted)
    }

    var urlString: URL? {
        guard maybeURL else { return nil }
        guard let url = URL(string: self) ?? URL(string: "https://" + self) else { return nil }
        return url
    }

    func urlRangesInside() -> [NSRange]? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))

        return matches.compactMap({ $0.range })
    }

    func validUrl() -> (isValid: Bool, url: String) {
        guard let url = URL(string: self) else { return (false, "") }

        let isContainsScheme = ["http", "https"].contains(url.scheme)

        if !url.pathExtension.isEmpty || isContainsScheme {
            return (true, isContainsScheme ? self : "http://\(url)")
        }

        return (false, "")
    }

}
