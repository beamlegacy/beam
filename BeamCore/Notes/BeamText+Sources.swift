//
//  BeamText+Sources.swift
//  BeamCore
//
//  Created by Stef Kors on 25/11/2021.
//

import Foundation

public extension BeamText {
    /// All sources in BeamText. Returns empty array if no source ranges are found.
    var sources: [SourceMetadata] {
        ranges.compactMap { $0.source }
    }

    /// All source ranges in BeamText. Returns empty array if no source ranges are found.
    var sourceRanges: [Range] {
        ranges.compactMap { $0.source == nil ? nil : $0 }
    }

    /// Strip source attribute from attribute array
    static func removeSources(from attributes: [Attribute]) -> [Attribute] {
        return attributes.compactMap({ $0.isSource ? nil : $0 })
    }

    /// Returns true if text contains source range referencing a specific NoteId
    func hasSourceToNote(id noteId: UUID) -> Bool {
        sourceRanges.contains(where: { range in
            range.source?.origin == .local(noteId)
        })
    }

    /// Returns true if text contains source range referencing a specific url string
    func hasSourceToWeb(url: URL) -> Bool {
        sourceRanges.contains(where: { range in
            range.source?.origin == .remote(url)
        })
    }

    /// Return text string with all source attributes removed
    var textWithSourcesErased: String {
        ranges.compactMap({ range -> Range? in
            for attribute in range.attributes {
                switch attribute {
                case .source:
                    return nil
                default:
                    break
                }
            }
            return range
        }).reduce(String()) { (string, range) -> String in
            string + range.string
        }
    }
}
