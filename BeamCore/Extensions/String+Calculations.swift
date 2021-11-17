//
//  String+Calculations.swift
//  BeamCore
//
//  Created by Remi Santos on 08/04/2021.
//

import Foundation
import AppKit

public extension String {
    var numberOfWords: Int {
        var count = 0
        let range = startIndex..<endIndex
        enumerateSubstrings(in: range, options: [.byWords, .substringNotRequired, .localized], { _, _, _, _ -> Void in
            count += 1
        })
        return count
    }

    func countInstances(of stringToFind: String) -> [NSRange] {
        guard stringToFind.count > 0 else { return [] }
        var count = 0
        var searchRange: Range<String.Index>?
        var ranges: [NSRange] = []

        while let foundRange = range(of: stringToFind, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            count += 1
            searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: endIndex))
            ranges.append(NSRange(foundRange, in: self))
        }
        return ranges
    }

    func widthOfString(usingFont font: NSFont) -> CGFloat {
         let fontAttributes = [NSAttributedString.Key.font: font]
         let size = self.size(withAttributes: fontAttributes)
         return size.width
     }
}
