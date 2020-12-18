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

    enum Attribute: Codable {
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

            switch self {
            case .strong:
                try container.encode(0, forKey: .type)
            case .emphasis:
                try container.encode(1, forKey: .type)
            case .source(let value):
                try container.encode(2, forKey: .type)
                try container.encode(value, forKey: .payload)
            case .link(let value):
                try container.encode(3, forKey: .type)
                try container.encode(value, forKey: .payload)
            case .internalLink(let value):
                try container.encode(4, forKey: .type)
                try container.encode(value, forKey: .payload)
            case .heading(let value):
                try container.encode(5, forKey: .type)
                try container.encode(value, forKey: .payload)
            case .quote(let value):
                try container.encode(6, forKey: .type)
                try container.encode(value, forKey: .payload)
            }
        }
    }

    struct Range: Codable {
        var string: String
        var attributes: [Attribute]
    }
    var ranges: [Range] = []

    init(text: String, attributes: [Attribute] = []) {
        self.ranges.append(Range(string: text, attributes: attributes))
    }

    func range(at: Int) throws -> Range {
        var position = 0
        for range in ranges {
            let length = range.string.count
            if position <= at && at < position + length {
                return range
            }

            position += length
        }

        throw BeamTextError.rangeNotFound
    }

    private func splitRange(at: Int) throws -> (Int, Range) {
        
    }

}
