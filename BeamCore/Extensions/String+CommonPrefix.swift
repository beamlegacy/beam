//
//  String+CommonPrefix.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 19/01/2022.
//

import Foundation

public extension String {
    private static let commonPrefixStarterCharacterSet = CharacterSet.punctuationCharacters.union(CharacterSet.whitespacesAndNewlines)
    func longestCommonPrefixRange(_ prefix: String, options: CompareOptions = .caseInsensitive) -> Range<Int>? {
        var p = prefix

        while !p.isEmpty {
            if let idx = range(of: p, options: options)?.lowerBound {
                if idx == startIndex {
                    return 0 ..< p.count
                }

                // Test that the previous char is a blank or ponctuation
                let previousIndex = index(before: idx)
                let previousChar = self[previousIndex ..< idx]
                if nil != previousChar.rangeOfCharacter(from: Self.commonPrefixStarterCharacterSet) {
                    let pos = position(at: idx)
                    return pos ..< pos + p.count
                }
            }

            p = String(p.prefix(p.count - 1))
        }
        return nil
    }
}
