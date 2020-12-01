//
//  BeamNote.swift
//  testWkWebViewSwiftUI
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import AppKit

/*
 
 Beam contains Notes
 A Note contains a tree of blocks. A Note has a title that has to be unique.
 A Block contains a list of text blocks. An element can be of different type (Bullet point, Numbered bullet point, Quote, Code, Header (1-6?)...). A Block can be referenced by any note
 A text block contains text. It contains the format of the text (Bold, Italic, Underline). There are different text block types to represent different attributes (Code, URL, Link...)
 */

struct VisitedPage: Codable, Identifiable {
    var id: UUID = UUID()

    var originalSearchQuery: String
    var url: URL
    var date: Date
    var duration: TimeInterval
}

struct NoteReference: Codable {
    var noteName: String
    var elementID: UUID
}

// Document:
class BeamNote: BeamElement {
    public var title: String

    var type: NoteType = .note
    var outLinks: [String] = [] ///< The links contained in this note
    var linkedReferences: [NoteReference] = [] ///< urls of the notes/bullet pointing to this note explicitely
    var unlinkedReferences: [NoteReference] = [] ///< urls of the notes/bullet pointing to this note implicitely

    var searchQueries: [String] = [] ///< Search queries whose results were used to populate this note
    var visitedSearchResults: [VisitedPage] = [] ///< URLs whose content were used to create this note

    init(title: String) {
        self.title = title
        super.init()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case outLinks
        case searchQueries
        case visitedSearchResults
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NoteType.self, forKey: .type)
        outLinks = try container.decode([String].self, forKey: .outLinks)
        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)

        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(outLinks, forKey: .outLinks)
        try container.encode(searchQueries, forKey: .searchQueries)
        try container.encode(visitedSearchResults, forKey: .visitedSearchResults)

        try super.encode(to: encoder)
    }

    func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            let str = String(data: data, encoding: .utf8)
            print(str!)

            guard let documentStruct = DocumentStruct(id: id, title: title, data: data, documentType: type == .journal ? .journal : .note) else {
                completion?(.success(false))
                return
            }

            documentManager.saveDocument(documentStruct) { result in
                completion?(result)
            }
        } catch {
            completion?(.failure(error))
        }
    }

}

// TODO: Remove this when we remove Note/Bullet from the build
// temp adapter
func beamNoteFrom(note: Note) -> BeamNote {
    let n = BeamNote(title: note.title)

    for b in note.rootBullets() {
        n.addChild(beamElementFrom(bullet: b))
    }

    return n
}

func beamElementFrom(bullet: Bullet) -> BeamElement {
    let element = BeamElement()
    element.text = bullet.content

    for b in bullet.sortedChildren() {
        element.addChild(beamElementFrom(bullet: b))
    }

    return element
}
