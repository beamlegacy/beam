//
//  String+Slice.swift
//  BeamCore
//
//  Created by Stef Kors on 18/06/2021.
//  Source: https://stackoverflow.com/a/52514158/3199999

import Foundation

public extension String {
    /// Usage: `let slicedString = yourString.slice(from: "\"", to: "\"")`
    /// - Parameters:
    ///   - from: String to start range
    ///   - to: String to end range
    /// - Returns: Sliced string between `from` and `to`
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }

    func dropBefore(substring: String) -> String? {
        guard let prefixRange = self.range(of: substring) else { return nil }
        let newStartIndex = self.index(prefixRange.lowerBound, offsetBy: 0)
        return String(self[newStartIndex...])
    }

    // credit: https://gist.github.com/budidino/8585eecd55fd4284afaaef762450f98e?permalink_comment_id=2270476#gistcomment-2270476
    enum TruncationPosition {
        case head
        case middle
        case tail
    }

    func truncated(limit: Int, position: TruncationPosition = .tail, leader: String = "…") -> String {
        guard self.count > limit else { return self }

        switch position {
        case .head:
            return leader + self.suffix(limit)
        case .middle:
            let headCharactersCount = Int(ceil(Float(limit - leader.count) / 2.0))

            let tailCharactersCount = Int(floor(Float(limit - leader.count) / 2.0))

            return "\(self.prefix(headCharactersCount))\(leader)\(self.suffix(tailCharactersCount))"
        case .tail:
            return self.prefix(limit) + leader
        }
    }
}
