//
//  BeamText.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/12/2020.
//
// swiftlint:disable file_length

import Foundation

//swiftlint:disable:next type_body_length
public struct BeamText: Codable {
    public var text: String {
        ranges.reduce(String()) { (string, range) -> String in
            string + range.string
        }
    }

    public enum Attribute: Codable, Equatable, Hashable {

        case strong
        case emphasis
        case source(SourceMetadata)
        case link(String)
        case internalLink(UUID)
        case strikethrough
        case underline
        /// meant for UI temporary styling; will not be persisted
        case decorated(AttributeDecoratedValue)

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case payload
            case level
            case title
            case source
        }

        var shouldBeSaved: Bool {
            switch self {
            case .decorated:
                return false
            default:
                return true
            }
        }
        // swiftlint:disable:next nesting
        public enum AttributeError: Error {
            case unknownAttribute
            case noNoteWithName(String)
        }

        // swiftlint:disable:next cyclomatic_complexity
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                let type = try container.decode(String.self, forKey: .type)
                switch type {
                case "strong": self = .strong
                case "emphasis": self = .emphasis
                case "source":
                    if let src = try? container.decodeIfPresent(SourceMetadata.self, forKey: .payload) {
                        self = .source(src)
                    } else {
                        self = .source(SourceMetadata(string: try container.decode(String.self, forKey: .payload)))
                    }
                case "link": self = .link(try container.decode(String.self, forKey: .payload))
                case "internalLink":
                    if let string = try? container.decode(String.self, forKey: .payload) {
                        // this is the old type of link that contains string instead of UUIDs, let's translate that
                        guard let uuid = UUID(uuidString: string) ?? BeamNote.idForNoteNamed(string, false) else {
                            throw AttributeError.noNoteWithName(string)
                        }
                        self = .internalLink(uuid)
                    } else {
                        self = .internalLink(try container.decode(UUID.self, forKey: .payload))
                    }
                case "strikethrough": self = .strikethrough
                case "underline": self = .underline
                case "decorated": self = .decorated(AttributeDecoratedValue())
                default:
                    throw AttributeError.unknownAttribute
                }
            } catch {
                let type = try container.decode(Int.self, forKey: .type)
                switch type {
                case 0: self = .strong
                case 1: self = .emphasis
                case 2: self = .source(try container.decode(SourceMetadata.self, forKey: .payload))
                case 3: self = .link(try container.decode(String.self, forKey: .payload))
                case 4: self = .internalLink(try container.decode(UUID.self, forKey: .payload))
                case 5: self = .strikethrough
                case 6: self = .underline
                case 7: self = .decorated(AttributeDecoratedValue())
                default:
                    throw AttributeError.unknownAttribute
                }
            }
        }

        public func encode(to encoder: Encoder) throws {
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
            case .strikethrough: break
            case .underline: break
            case .decorated: break
            }
        }

        public var rawValue: String {
            switch self {
            case .strong:
                return "strong"
            case .emphasis:
                return "emphasis"
            case .source:
                return "source"
            case .link:
                return "link"
            case .internalLink:
                return "internalLink"
            case .strikethrough:
                return "strikethrough"
            case .underline:
                return "underline"
            case .decorated:
                return "decorated"
            }
        }

        public var isLink: Bool {
            switch self {
            case .link:
                return true
            case .internalLink:
                return true
            default:
                return false
            }
        }

        public var isInternalLink: Bool {
            switch self {
            case .internalLink:
                return true
            default:
                return false
            }
        }

        /// Return true if BeamText is of source type
        public var isSource: Bool {
            switch self {
            case .source:
                return true
            default:
                return false
            }
        }

        public var isEditable: Bool {
            switch self {
            case .link, .internalLink:
                return false
            case .decorated(let value):
                return value.isEditable
            default:
                return true
            }
        }
    }

    open class AttributeDecoratedValue: Equatable, Hashable {
        public static func == (lhs: AttributeDecoratedValue, rhs: AttributeDecoratedValue) -> Bool {
            false
        }

        public var isEditable: Bool = false
        public init() { }
        public func hash(into hasher: inout Hasher) {
            // not hashable
        }
    }

    public struct Range: Codable, Equatable {
        public var string: String
        public var resolvedString: String? {
            guard let noteId = internalLink else {
                return string
            }
            return BeamNote.titleForNoteId(noteId, false)
        }
        public var attributes: [Attribute]

        public var position: Int
        public var end: Int { position + string.count }
        public var range: Swift.Range<Int> { position ..< end }

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case string
            case attributes
        }

        public init(string: String = "", attributes: [Attribute] = [], position: Int = 0) {
            self.string = string
            self.attributes = attributes
            self.position = position
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            string = try container.decode(String.self, forKey: .string)
            attributes = (try? container.decode([Attribute].self, forKey: .attributes)) ?? []
            position = 0
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(string, forKey: .string)
            if !attributes.isEmpty {
                let attributesToSave = attributes.filter { $0.shouldBeSaved }
                try container.encode(attributesToSave, forKey: .attributes)
            }
        }

        public var internalLink: UUID? {
            for attribute in attributes {
                if case let .internalLink(linkId) = attribute {
                    return linkId
                }
            }
            return nil
        }

        public var source: SourceMetadata? {
            for attribute in attributes {
                if case let .source(source) = attribute {
                    return source
                }
            }
            return nil
        }

        @discardableResult
        public mutating func resolveString() -> String? {
            let value = resolvedString
            string = value ?? string
            return value
        }

        public func resolved() -> Self {
            var new = self
            let hasResolvedString = new.resolveString()
            if hasResolvedString == nil, internalLink != nil {
                new.attributes.removeAll { $0.isInternalLink }
            }
            return new
        }
    }

    /// - Returns: true is something was actually updated
    public mutating func resolveNotesNames() -> Bool {
        if !internalLinks.isEmpty {
            let newRanges = ranges.map({ $0.resolved() })
            if newRanges != ranges {
                ranges = newRanges
            }
            return true
        }
        return false
    }

    public var ranges: [Range]

    public init(text: String = "", attributes: [Attribute] = []) {
        self.ranges = [Range(string: text, attributes: attributes, position: 0)]
    }
    public init(text: BeamText, attributes: [Attribute] = []) {
        var newText = text
        newText.addAttributes(attributes, to: newText.wholeRange)
        self.ranges = newText.ranges
    }

    // swiftlint:disable:next nesting
    enum CodingKeys: String, CodingKey {
        case ranges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        ranges = (try? container.decode([Range].self, forKey: .ranges)) ?? []
        flatten()
        computePositions()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if !ranges.isEmpty {
            try container.encode(ranges, forKey: .ranges)
        }
    }

    public func rangeAt(position: Int) -> Range {
        guard let index = rangeIndexAt(position: clamp(position)) else { fatalError() }
        return ranges[index]
    }

    public func rangeIndexAt(position: Int) -> Int? {
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
    mutating internal func splitRangeAt(position: Int, createEmptyRanges: Bool) -> Int {
        let position = min(max(position, 0), count)
        var pos = 0
        for (i, range) in ranges.enumerated() {
            let length = range.string.count
            if pos <= position && position <= pos + length {
                let offset = position - pos
                if !createEmptyRanges {
                    if offset == 0 { return max(0, i - 1) }
                    if offset == length { return i + 1 }
                }
                let newRange1 = Range(string: String(range.string.prefix(offset)), attributes: range.attributes, position: range.position)
                let newRange2 = Range(string: String(range.string.suffix(length - offset)), attributes: range.attributes, position: range.position + offset)
                ranges[i] = newRange1
                if i + 1 < ranges.count {
                    ranges.insert(newRange2, at: i + 1)
                } else {
                    ranges.append(newRange2)
                }

                return i + 1
            }

            pos += length
        }

        fatalError()
    }

    public mutating func addAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes.append(contentsOf: attributes)
        }

        flatten()
        computePositions()
    }

    public mutating func setAttributes(_ attributes: [Attribute], to positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        for i in index0 ..< index1 {
            ranges[i].attributes = attributes
        }

        flatten()
        computePositions()
    }

    public mutating func removeAttributes(_ attributes: [Attribute], from positionRange: Swift.Range<Int>) {
        let index0 = splitRangeAt(position: positionRange.lowerBound, createEmptyRanges: false)
        let index1 = splitRangeAt(position: positionRange.upperBound, createEmptyRanges: false)

        let rawAttributes = attributes.map { attribute -> String in attribute.rawValue }
        for i in index0 ..< index1 {
            ranges[i].attributes.removeAll(where: { attribute -> Bool in
                rawAttributes.contains(attribute.rawValue)
            })
        }

        flatten()
        computePositions()
    }

    /// de-duplicate similar ranges
    mutating internal func flatten() {
        guard silent == 0 else { return }
        var newRanges: [Range] = []
        for range in ranges {
            // Only remove empty strings if it makes sense, that is if it's not the only range
            guard !range.string.isEmpty || ranges.count == 1 else { continue }
            guard var last = newRanges.last else { newRanges.append(range); continue }
            guard last.attributes == range.attributes else { newRanges.append(range); continue }

            last.string += range.string
            newRanges.removeLast()
            newRanges.append(last)
        }

        ranges = newRanges
        if ranges.isEmpty {
            ranges.append(Range())
        }

        computePositions()
    }

    var silent = 0

    /// recompute the positions of the ranges, starting at the given 'from' index
    mutating internal func computePositions(from: Int = 0) {
        var pos = from == 0 ? 0 : ranges[from].position
        for index in from ..< ranges.count {
            ranges[index].position = pos
            pos += ranges[index].string.count
        }
    }

    /// insert the given string at the given index
    public mutating func insert(_ text: String, at position: Int) {
        guard var last = ranges.last else {
            ranges.append(Range(string: text, attributes: [], position: position))
            return
        }

        guard position < last.end else {
            last.string += text
            ranges.removeLast()
            ranges.append(last)
            return
        }

        let position = clamp(position)
        guard let index = rangeIndexAt(position: position) else { fatalError() }
        let offset = position - ranges[index].position
        ranges[index].string.insert(contentsOf: text, at: ranges[index].string.index(at: offset))

        computePositions(from: index)
        flatten()
    }

    /// insert the given string at the given index, with given attributes
    public mutating func insert(_ text: String, at position: Int, withAttributes attributes: [Attribute]) {
        guard position != ranges.last?.end
        else {
            ranges.append(Range(string: text, attributes: attributes, position: position))
            flatten()
            computePositions()
            return }
        let index = splitRangeAt(position: position, createEmptyRanges: false)
        let range = Range(string: text, attributes: attributes, position: position)
        ranges.insert(range, at: index)

        flatten()
        computePositions()
    }

    public mutating func append(_ text: String, withAttributes attributes: [Attribute]) {
        ranges.append(Range(string: text, attributes: attributes, position: ranges.last?.end ?? 0))
        flatten()
    }

    public mutating func append(_ text: String) {
        guard var range = ranges.last
        else {
            append(text, withAttributes: [])
            computePositions()
            return
        }
        range.string += text
        ranges[ranges.endIndex - 1] = range
        flatten()
    }

    public mutating func removeSubrangeSilent(_ range: Swift.Range<Int>) {
        self.remove(count: range.count, at: range.lowerBound)
        if ranges.isEmpty {
            ranges.append(Range())
        }
    }

    public mutating func removeSubrange(_ range: Swift.Range<Int>) {
        guard range != wholeRange else {
            ranges = [Range()]
            return
        }

        self.remove(count: range.count, at: range.lowerBound)
        if ranges.isEmpty {
            ranges.append(Range())
        }

        flatten()
        computePositions()
    }

    public mutating func remove(count: Int, at position: Int) {
        guard count > 0 else { return }
        let index0 = splitRangeAt(position: position, createEmptyRanges: false)
        let index1 = splitRangeAt(position: position + count, createEmptyRanges: false)

        ranges.removeSubrange(index0 ..< index1)

        flatten()
        computePositions()
    }

    /// Insert BeamText:
    public mutating func insert(_ text: BeamText, at position: Int) {
        var pos = position
        for range in text.ranges {
            insert(range.string, at: pos, withAttributes: range.attributes)
            pos += range.string.count
        }
    }

    public mutating func append(_ text: BeamText) {
        for range in text.ranges {
            append(range.string, withAttributes: range.attributes)
        }
    }

    public mutating func append(contentsOf: [BeamText]) {
        for text in contentsOf {
            append(text)
        }
    }

    public func extract(range: Swift.Range<Int>) -> BeamText {
        var newText = self
        let endLength = text.count - range.upperBound
        newText.removeLast(endLength)
        newText.removeFirst(range.lowerBound)
        return newText
    }

    public var isEmpty: Bool { ranges.isEmpty || text.isEmpty }
    public var count: Int {
        return ranges.last?.end ?? 0
    }

    public mutating func removeFirst(_ count: Int) {
        let selfCount = self.count
        let c = min(count, selfCount)
        remove(count: c, at: 0)
    }

    public mutating func removeLast(_ count: Int) {
        let selfCount = self.count
        let c = min(count, selfCount)
        remove(count: c, at: selfCount - c)
    }
}
