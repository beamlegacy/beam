//
//  String+URL.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation
import TLDExtract

public extension String {
    var markdownizedURL: String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "()").inverted)
    }

    var toEncodedURL: URL? {
        guard mayBeURL,
              let encodedString = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) ?? URL(string: self)
        else { return nil }
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

        if self.mayBeEmail {
            return (true, "mailto:\(self)")
        }
        if !url.pathExtension.isEmpty || url.scheme != nil {
            return (true, url.scheme != nil ? self : "https://\(url)")
        }

        return (false, "")
    }

    private static var TLDextractor: TLDExtract = {
        //swiftlint:disable:next force_try
        try! TLDExtract(useFrozenData: true)
    }()

    var tld: String? {
        Self.TLDextractor.parse(self)?.rootDomain
    }
}
