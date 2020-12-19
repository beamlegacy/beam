//
//  BeamText.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/12/2020.
//

import Foundation

enum BeamTextError: Error {
    case rangeNotFound
}

class BeamText: Codable {
    var text: String {
        ranges.reduce(String()) { (string, range) -> String in
            string + range.string
        }
    }

    enum Attribute: Codable, Equatable {
        case strong
        case emphasis
        case source(String)
        case link(String)
        case internalLink(String)
        case heading(Int)
        case quote(Int, String, String) // level, title, source

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case payload
            case level
            case title
            case source
        }

        // swiftlint:disable:next nesting
        enum AttributeError: Error {
            case unknownAttribute
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = try container.decode(Int.self, forKey: .type)
            switch type {
            case 0: self = .strong
            case 1: self = .emphasis
            case 2: self = .source(try container.decode(String.self, forKey: .payload))
            case 3: self = .link(try container.decode(String.self, forKey: .payload))
            case 4: self = .internalLink(try container.decode(String.self, forKey: .payload))
            case 5: self = .heading(try container.decode(Int.self, forKey: .payload))
            case 6: self = .quote(try container.decode(Int.self, forKey: .level), try container.decode(String.self, forKey: .title), try container.decode(String.self, forKey: .source))
            default:
                throw AttributeError.unknownAttribute
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.rawValue, forKey: .type)

            switch self {
            case .strong: break
            case .emphasis: break
            case .source(let value):
                try container.encode(value, forKey: .payload)
            case .link(let value):
                try container.encode(value, forKey: .payload)
            case .internalLink(let value):
                try container.encode(value, forKey: .payload)
            case .heading(let value):
                try container.encode(value, forKey: .payload)
            case let .quote(level, title, source):
                try container.encode(level, forKey: .level)
                try container.encode(title, forKey: .title)
                try container.encode(source, forKey: .source)
            }
        }

        var rawValue: Int {
            switch self {
            case .strong:
                return 0
            case .emphasis:
                return 1
            case .source:
                return 2
            case .link:
                return 3
            case .internalLink:
                return 4
            case .heading:
                return 5
            case .quote:
                return 6
            }
        }
    }

    struct Range: Codable, Equatable {
        var string: String = ""
        var attributes: [Attribute] = []
        var position: Int = 0

        var end: Int { position + string.count }
    }
    var ranges: [Range] = [Range(string: "", attributes: [], position: 0)]

    init(text: String = "", attributes: [Attribute] = []) {
        self.ranges.append(Range(string: text, attributes: attributes, position: 0))
    }

    func rangeAt(position: Int) -> Range {
        guard let index = rangeIndexAt(position: clamp(position)) else { fatalError() }
        return ranges[index]
    }

    func rangeIndexAt(position: Int) -> Int? {
        var pos = 0
        for (i, range) in ranges.enumerated() {
            let length = range.string.count
            if pos <= position && position <= pos + length {
                return i
            }

            pos += length
        }

        return nil
    }

    /// split a range in two at the given position in preparation, Any of the resulting ranges may be empty. The return value is the index of the first half
    private func splitRangeAt(position: Int, createEmptyRanges: Bool) -> Int {
        let position = min(max(position, 0), count)
        var pos = 0
        for (i, range) in ranges.enumerated() {
            let length = range.string.count
            if pos <= position && position <= pos + length {
                let offset = position - pos
                if !createEmptyRanges {
                    if offset == 0 { return max(0, i - 1) }
                    if offset == length { return i }
                }
                let newRange1 = Range(string: String(range.string.prefix(offset)), attributes: range.attributes, position: range.position)
                let newRange2 = Range(string: String(range.string.suffix(length - offset)), attributes: range.attributes, position: range.position + offset)
                ranges[i] = newRange1
                if i + 1 < ranges.count {
                    ranges.insert(newRange2, at: i + 1)
                } else {
                    ranges.append(newRange2)
                }

                return i
            }

            pos += length
        }

        fatalError()
    }

    func addAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes.append(contentsOf: attributes)
        }

        flatten()
    }

    func setAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes = attributes
        }

        flatten()
    }

    func removeAttributes(_ attributes: [Attribute], from positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        let rawAttributes = attributes.map { attribute -> Int in attribute.rawValue }
        for i in index0 ..< index1 {
            ranges[i].attributes.removeAll(where: { attribute -> Bool in
                rawAttributes.contains(attribute.rawValue)
            })
        }

        flatten()
    }

    /// de-duplicate similar ranges
    internal func flatten() {
        var newRanges: [Range] = []
        for range in ranges {
            guard var last = newRanges.last else { newRanges.append(range); continue }
            guard last.attributes != range.attributes else { newRanges.append(range); continue }

            last.string += range.string
            newRanges.removeLast()
            newRanges.append(last)
        }

        ranges = newRanges
    }

    /// recompute the positions of the ranges, starting at the given 'from' index
    internal func computePositions(from: Int = 0) {
        var pos = from == 0 ? 0 : ranges[from].position
        for index in from ..< ranges.count {
            ranges[index].position = pos
            pos += ranges[index].string.count
        }
    }

    /// insert the given string at the given index
    func insert(_ text: String, at position: Int) {
        guard position != ranges.last?.end else { ranges.append(Range(string: text, attributes: [], position: position)); return }
        let position = clamp(position)
        guard let index = rangeIndexAt(position: position) else { fatalError() }
        let offset = position - ranges[index].position
        ranges[index].string.insert(contentsOf: text, at: ranges[index].string.index(at: offset))

        computePositions(from: index)
    }

    /// insert the given string at the given index, with given attributes
    func insert(_ text: String, at position: Int, withAttributes attributes: [Attribute]) {
        guard position != ranges.last?.end else { ranges.append(Range(string: text, attributes: attributes, position: position)); return }
        let index = splitRangeAt(position: position, createEmptyRanges: true)
        let range = Range(string: text, attributes: attributes, position: position)
        ranges.insert(range, at: index + 1)

        flatten()
        computePositions()
    }

    func append(_ text: String, withAttributes attributes: [Attribute]) {
        ranges.append(Range(string: text, attributes: attributes, position: ranges.last?.end ?? 0))
    }

    func append(_ text: String) {
        guard var range = ranges.last else { append(text, withAttributes: []); return }
        range.string += text
        ranges[ranges.endIndex - 1] = range
    }

    func removeSubrange(_ range: Swift.Range<Int>) {
        self.remove(count: range.count, at: range.lowerBound)
        if ranges.isEmpty {
            ranges.append(Range())
        }
    }

    func remove(count: Int, at position: Int) {
        guard count > 0 else { return }
        let index0 = splitRangeAt(position: position, createEmptyRanges: true)
        let index1 = splitRangeAt(position: position + count, createEmptyRanges: true)

        ranges.removeSubrange(index0 + 1 ..< index1 + 1)
        flatten()
        computePositions()
    }

    /// Insert BeamText:
    func insert(_ text: BeamText, at position: Int) {
        var pos = position
        for range in text.ranges {
            insert(range.string, at: pos, withAttributes: range.attributes)
            pos += range.string.count
        }
    }

    func append(_ text: BeamText) {
        for range in text.ranges {
            append(range.string, withAttributes: range.attributes)
        }
    }

    func extract(range: Swift.Range<Int>) -> BeamText {
        let newText = self
        let endLength = text.count - range.upperBound
        newText.removeLast(endLength)
        newText.removeFirst(range.lowerBound)
        return newText
    }

    var isEmpty: Bool { ranges.isEmpty || text.isEmpty }
    var count: Int {
        return ranges.last?.end ?? 0
    }

    func removeFirst(_ count: Int) {
        let selfCount = self.count
        let c = min(count, selfCount)
        remove(count: c, at: 0)
    }

    func removeLast(_ count: Int) {
        let selfCount = self.count
        let c = min(count, selfCount)
        remove(count: c, at: selfCount - c)
    }
}

// String additions:
extension BeamText {
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

    func replaceSubrange(_ range: Swift.Range<Int>, with string: String) {
        removeSubrange(range)
        insert(string, at: range.lowerBound)
    }

    func replaceSubrange(_ range: Swift.Range<Int>, with text: BeamText) {
        removeSubrange(range)
        insert(text, at: range.lowerBound)
    }

    func hasPrefix(_ string: String) -> Bool {
        return text.hasPrefix(string)
    }
}

extension BeamText: Equatable {
    static func == (lhs: BeamText, rhs: BeamText) -> Bool {
        return lhs.ranges == rhs.ranges
    }

}
