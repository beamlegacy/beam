//
//  String+URL.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation
import TLDExtractSwift

private extension CharacterSet {
    static var beamURLQueryAllowed: CharacterSet {
        .urlQueryAllowed.union(CharacterSet(charactersIn: "#"))
    }
}

public extension String {
    var markdownizedURL: String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "()").inverted)
    }

    private var isPercentEncoded: Bool {
        self.removingPercentEncoding != self
    }

    var toEncodedURL: URL? {
        guard mayBeURL else {
            return nil
        }

        if isPercentEncoded {
            return URL(string: self)
        }

        if let encodedString = self.addingPercentEncoding(withAllowedCharacters: .beamURLQueryAllowed) {
            return URL(string: encodedString)
        }

        return URL(string: self)
    }

    func urlRangesInside() -> [NSRange]? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))

        return matches.compactMap({ $0.range })
    }

    func validUrl() -> (isValid: Bool, url: String) {
        guard self.tld != nil, let url = URL(string: self) else { return (false, "") }

        if self.mayBeEmail {
            return (true, "mailto:\(self)")
        }
        if !url.pathExtension.isEmpty || url.scheme != nil {
            return (true, url.scheme != nil ? self : "https://\(url)")
        }

        return (false, "")
    }

    private static var TLDextractor: TLDExtract = {
        try! TLDExtract(useFrozenData: true)
    }()

    var tld: String? {
        Self.TLDextractor.parse(self)?.rootDomain
    }

    var containsCharacters: Bool {
        return !self.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
