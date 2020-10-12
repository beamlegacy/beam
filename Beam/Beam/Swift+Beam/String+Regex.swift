//
//  String+Regex.swift
//  Beam
//
//  Created by Sebastien Metrot on 10/10/2020.
//

import Foundation

public extension String {
    func capturedGroups(withRegex pattern: String) -> [String] {
        var results = [String]()
        let ranges = capturedRanges(withRegex: pattern)
        for r in ranges {
            results.append(substring(range: r))
        }
        return results
    }

    func capturedRanges(withRegex pattern: String) -> [Range<Int>] {
        var results = [Range<Int>]()

        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))

        guard let match = matches.first else { return results }

        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }

        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.range(at: i)
            results.append(capturedGroupIndex.lowerBound..<capturedGroupIndex.upperBound)
        }

        return results
    }
}
