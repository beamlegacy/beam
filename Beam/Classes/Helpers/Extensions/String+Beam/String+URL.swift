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

    func urlRangesInside() -> [NSRange]? {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        
        return matches.compactMap({$0.range})
    }

    var isValidUrl: Bool {
        let types: NSTextCheckingResult.CheckingType = [.link]
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        let detector = try! NSDataDetector(types: types.rawValue)
        var isValid = false

        detector.enumerateMatches(in: self, options: [], range: range) { (match, _, _) in
            guard let match = match else { return }

            switch match.resultType {
            case .link:
                isValid = true
            default:
                break
            }
        }

        return isValid
    }
}
