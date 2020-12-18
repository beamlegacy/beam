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
        case quote(Int)

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case payload
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
            case 6: self = .quote(try container.decode(Int.self, forKey: .payload))
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
            case .quote(let value):
                try container.encode(value, forKey: .payload)
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

    struct Range: Codable {
        var string: String
        var attributes: [Attribute]
        var position: Int
    }
    var ranges: [Range] = []

    init(text: String = "", attributes: [Attribute] = []) {
        self.ranges.append(Range(string: text, attributes: attributes, position: 0))
    }

    func rangeAt(position: Int) throws -> Range {
        let index = try rangeIndexAt(position: position)
        return ranges[index]
    }

    func rangeIndexAt(position: Int) throws -> Int {
        var pos = 0
        for (i, range) in ranges.enumerated() {
            let length = range.string.count
            if pos <= position && position < pos + length {
                return i
            }

            pos += length
        }

        throw BeamTextError.rangeNotFound
    }

    /// split a range in two at the given position in preparation, Any of the resulting ranges may be empty. The return value is the index of the first half
    private func splitRangeAt(position: Int, createEmptyRanges: Bool) throws -> Int {
        var pos = 0
        for (i, range) in ranges.enumerated() {
            let length = range.string.count
            if pos <= position && position < pos + length {
                let offset = pos + length - position
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

        throw BeamTextError.rangeNotFound
    }

    func addAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) throws {
        let index0 = try splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = try splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes.append(contentsOf: attributes)
        }

        flatten()
    }

    func setAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) throws {
        let index0 = try splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = try splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes = attributes
        }

        flatten()
    }

    func removeAttributes(_ attributes: [Attribute], from positionRange: Swift.Range<Int>) throws {
        let index0 = try splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = try splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

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
            guard last.attributes != range.attributes else { continue }

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
    func insert(text: String, at position: Int) throws {
        let index = try rangeIndexAt(position: position)
        var range = ranges[index]
        let offset = position - range.position
        range.string.insert(contentsOf: text, at: range.string.index(at: offset))

        computePositions(from: index)
    }

    /// insert the given string at the given index, with given attributes
    func insert(text: String, at position: Int, withAttributes attributes: [Attribute]) throws {
        let index = try splitRangeAt(position: position, createEmptyRanges: true)
        let range = Range(string: text, attributes: attributes, position: position)
        ranges.insert(range, at: index)

        flatten()
        computePositions()
    }

    func remove(count: Int, at position: Int) throws {
        let index0 = try splitRangeAt(position: position, createEmptyRanges: false)
        let index1 = try splitRangeAt(position: position + count, createEmptyRanges: false)

        ranges.removeSubrange(index0 ..< index1)
        flatten()
        computePositions()
    }
}
