//
//  String+Ranges.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation

public extension String {
    func range(_ start: Int, _ end: Int) -> Range<String.Index> {
        return Range<String.Index>(uncheckedBounds: (lower: index(at: start), upper: index(at: end)))
    }

    func range(from r: Range<Int>) -> Range<String.Index> {
        return index(at: r.lowerBound)..<index(at: r.upperBound)
    }

    func clamp(_ range: Range<Int>) -> Range<Int> {
        let c = count
        var low = range.lowerBound
        var up = range.upperBound
        if low == NSNotFound {
            low = c
        }

        if up == NSNotFound {
            up = c
        }

        low = min(max(low, 0), count)
        up = min(max(up, low), count)
        return low..<up
    }

    func index(at position: Int) -> String.Index {
        if position == NSNotFound {
            return endIndex
        }
        if position >= 0 {
            if let i = index(startIndex, offsetBy: position, limitedBy: endIndex) {
                return i
            }
            return endIndex
        }
        if let i = index(endIndex, offsetBy: position, limitedBy: endIndex) {
            return i
        }
        return startIndex
    }

    var wholeRange: Range<Int> {
        return Int(0)..<Int(count)
    }

    func position(at index: String.Index) -> Int {
        return distance(from: startIndex, to: index)
    }

    func position(after pos: Int) -> Int {
        if pos < count {
            let i = index(at: pos)
            let newIndex = index(after: i)
            return position(at: newIndex)
        }
        return count
    }

    func position(before pos: Int) -> Int {
        if pos > 0 {
            let i = index(at: pos)
            let newIndex = index(before: i)
            return position(at: newIndex)
        }
        return 0
    }

    func description(_ range: Range<Index>) -> String {
        return "Range from \(position(at: range.lowerBound)) to \(position(at: range.upperBound)) [\(position(at: range.upperBound) - position(at: range.lowerBound))]"
    }

    func substring(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: to - from)
        return String(self[start ..< end])
    }

    subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
       let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        return String(self[start...])
   }

    func substring(range: Range<Int>) -> String {
        return substring(from: range.lowerBound, to: range.upperBound)
    }

    subscript(_ r: Range<Int>) -> Substring {
        self[self.range(from: r)]
    }

    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        let backwards = options.contains(.backwards)
        var options = options
        if backwards {
            options.remove(.backwards)
        }
        while startIndex < endIndex, let range = self[startIndex...].range(of: string, options: options) {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }

        return backwards ? result.reversed() : result
    }

    func range(from r: Range<String.Index>) -> Range<Int> {
        return position(at: r.lowerBound)..<position(at: r.upperBound)
    }

}

public extension String {
    /// Returns the start index of the group of characters that contains the given index
    func indexForCharactersGroup(before: Int) -> Int? {
        let textString = self
        var index: Int = 0
        let separator = CharacterSet.whitespaces
        textString.enumerateSubstrings(in: textString.startIndex..<textString.index(at: before),
                                       options: [.byComposedCharacterSequences, .reverse]) { (c, r1, _, stop) in
            if c?.rangeOfCharacter(from: separator) != nil {
                index = textString.position(at: r1.upperBound)
                stop = true
            }
        }
        return index
    }

    /// Returns the end index of the group of characters that contains the given index
    func indexForCharactersGroup(after: Int) -> Int? {
        let textString = self
        var index: Int = textString.wholeRange.upperBound
        let separator = CharacterSet.whitespaces
        textString.enumerateSubstrings(in: textString.index(at: after)..<textString.endIndex,
                                       options: .byComposedCharacterSequences) { (c, r1, _, stop) in
            if c?.rangeOfCharacter(from: separator) != nil {
                index = textString.position(at: r1.lowerBound)
                stop = true
            }
        }
        return index
    }
}
