//
//  NoteListMetadataCache.swift
//  Beam
//
//  Created by Remi Santos on 27/07/2021.
//

import Foundation
import BeamCore

struct NoteListMetadata {
    var links: Int
    var wordsCount: Int
}

class NoteListMetadataCache {

    static let shared = NoteListMetadataCache()

    private typealias NoteId = UUID

    private var cache = [NoteId: NoteListMetadata]()

    init() { }

    func metadata(for noteId: UUID) -> NoteListMetadata? {
        cache[noteId]
    }

    func saveMetadata(_ metadata: NoteListMetadata, for noteId: UUID) {
        cache[noteId] = metadata
    }

}
