//
//  BeamText+String.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import NaturalLanguage

//
// String additions:
public extension BeamText {
    func prefix(_ count: Int) -> BeamText {
        return extract(range: 0 ..< count)
    }

    func suffix(_ count: Int) -> BeamText {
        let len = self.count
        return extract(range: len - count ..< len)
    }

    func clamp(_ range: Swift.Range<Int>) -> Swift.Range<Int> {
        return text.clamp(range)
    }

    func clamp(_ position: Int) -> Int {
        return min(max(0, position), count)
    }

    func range(_ start: Int, _ end: Int) -> Swift.Range<String.Index> {
        return text.range(start, end)
    }

    func range(from r: Swift.Range<Int>) -> Swift.Range<String.Index> {
        return text.range(from: r)
    }

    func index(at position: Int) -> String.Index {
        return text.index(at: position)
    }

    var wholeRange: Swift.Range<Int> {
        return Int(0)..<Int(count)
    }

    func position(at index: String.Index) -> Int {
        return text.position(at: index)
    }

    func position(after pos: Int) -> Int {
        return text.position(after: pos)
    }

    func position(before pos: Int) -> Int {
        return text.position(before: pos)
    }

//    public func description(_ range: Range<Index>) -> String {
//        return "Range from \(position(at: range.lowerBound)) to \(position(at: range.upperBound)) [\(position(at: range.upperBound) - position(at: range.lowerBound))]"
//    }

    func substring(from: Int, to: Int) -> String {
        return text.substring(from: from, to: to)
    }

    func substring(range: Swift.Range<Int>) -> String {
        return text.substring(range: range)
    }

    mutating func replaceSubrange(_ range: Swift.Range<Int>, with string: String) {
        removeSubrange(range)
        insert(string, at: range.lowerBound)
    }

    mutating func replaceSubrange(_ range: Swift.Range<Int>, with text: BeamText) {
        removeSubrange(range)
        insert(text, at: range.lowerBound)
    }

    func backwardPairRangesSearch(of substring: String, from position: Int) -> (Swift.Range<Int>, Swift.Range<Int>)? {
        var endingRange: Swift.Range<Int>?
        let str = self.text.substring(from: 0, to: position)

        for range in str.ranges(of: substring, options: .backwards) {
            if let endingRange = endingRange {
                return (self.text.range(from: range), endingRange)
            }
            endingRange = self.text.range(from: range)
        }
        return nil
    }

    func hasPrefix(_ string: String) -> Bool {
        return text.hasPrefix(string)
    }

    func hasSuffix(_ string: String) -> Bool {
        return text.hasSuffix(string)
    }

    func trimming(_ charSet: CharacterSet) -> BeamText {
        var text = self
        let string = text.text
        let invCharSet = charSet.inverted
        let trimstart: String.Index? = string.firstIndex(where: { ch -> Bool in
            return ch.unicodeScalars.allSatisfy { scalar -> Bool in
                invCharSet.contains(scalar)
            }
        })
        let trimend: String.Index? = string.lastIndex(where: { ch -> Bool in
            return ch.unicodeScalars.allSatisfy { scalar -> Bool in
                invCharSet.contains(scalar)
            }
        })
        if let trimend = trimend {
            text.removeLast(string.count - string.position(at: trimend) - 1)
        }
        if let trimstart = trimstart {
            text.removeFirst(string.position(at: trimstart))
        }
        return text
    }

    /// Split BeamText by CharacterSet without mutating itself
    /// - Parameter charSet: NSCharacterSet
    /// - Returns: Array of BeamTexts
    func splitting(_ charSet: CharacterSet) -> [BeamText] {
        let text = self
        let string = text.text
        let splits = string.components(separatedBy: charSet)

        var start = 0
        let rangesSplit = splits.compactMap({ split -> BeamText? in
            let end: Int = start + split.count
            let range: Swift.Range<Int> = start..<end
            start = end + 1
            let extractedText = text.extract(range: range)

            if extractedText.text.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                return extractedText
            }

            return nil
        })

        return rangesSplit
    }
}

extension BeamText: Equatable {
    public static func == (lhs: BeamText, rhs: BeamText) -> Bool {
        return lhs.ranges == rhs.ranges
    }
}

public extension BeamText {
    var json: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return "<error while encoding \(self)>" }
        return String(data: data, encoding: .utf8) ?? "<error while making json string for \(self)>"
    }

    var jsonPretty: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return "<error while encoding \(self)>" }
        return String(data: data, encoding: .utf8) ?? "<error while making json string for \(self)>"
    }
}

public extension BeamText {

    func range(_ range: Swift.Range<Int>, containsAttribute attribute: BeamText.Attribute) -> Bool {
        let sub = extract(range: range)
        for range in sub.ranges {
            if range.attributes.contains(where: { attr -> Bool in attr.rawValue == attribute.rawValue }) {
                return true
            }
        }

        return false
    }

    // toggle the given attribute in the given range and return true if the attribute was added, false if it was removed
    @discardableResult mutating func toggle(attribute: BeamText.Attribute, forRange _range: Swift.Range<Int>) -> Bool {
        if range(_range, containsAttribute: attribute) {
            removeAttributes([attribute], from: _range)
            return false
        } else {
            addAttributes([attribute], to: _range)
            return true
        }
    }

    // return the range(s) that contains the position. If the position is in between two ranges, they are both returned
    func rangesAt(position: Int) -> [Range] {
        var lastRange: Range?
        for range in ranges {
            if range.position <= position && position <= range.end {
                if position == range.position, let last = lastRange {
                    return [last, range]
                }

                return [range]
            }
            lastRange = range
        }
        return []
    }
}

public extension BeamText {
    var wordRanges: [Swift.Range<Int>] {
        let t = text
        return t.wordRanges.map { t.range(from: $0) }
    }

    var sentenceRanges: [Swift.Range<Int>] {
        let t = text
        return t.sentenceRanges.map { t.range(from: $0) }
    }

    func tokenize(_ tokenUnit: NLTokenUnit, options: NLTagger.Options? = nil) -> [Swift.Range<Int>] {
        let t = text
        return t.tokenize(tokenUnit, options: options).map { t.range(from: $0) }
    }
}
