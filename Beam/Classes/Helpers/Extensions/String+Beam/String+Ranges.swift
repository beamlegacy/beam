//
//  String+Ranges.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation

extension String {
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

    public func description(_ range: Range<Index>) -> String {
        return "Range from \(position(at: range.lowerBound)) to \(position(at: range.upperBound)) [\(position(at: range.upperBound) - position(at: range.lowerBound))]"
    }

    func substring(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: to - from)
        return String(self[start ..< end])
    }

    func substring(range: Range<Int>) -> String {
        return substring(from: range.lowerBound, to: range.upperBound)
    }

    subscript(_ r: Range<Int>) -> Substring {
        self[self.range(from: r)]
    }
}
