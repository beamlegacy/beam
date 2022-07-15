//
//  BeamNoteDataHolder.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 10/03/2021.
//

import Foundation
import BeamCore

extension NSPasteboard.PasteboardType {
    static let noteDataHolder = NSPasteboard.PasteboardType("co.beamapp.macos.noteDataHolder")
}

class BeamNoteDataHolder: NSObject, Codable {

    var noteData: Data
    var imageData: [UUID: BeamFileRecord]

    init(noteData: Data, includedImages: [UUID: BeamFileRecord]) {
        self.noteData = noteData
        self.imageData = includedImages
    }

    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let data = propertyList as? Data,
            let elementHolder = try? PropertyListDecoder().decode(BeamNoteDataHolder.self, from: data) else { return nil }
        self.init(noteData: elementHolder.noteData, includedImages: elementHolder.imageData)
    }
}

extension BeamNoteDataHolder: NSPasteboardReading, NSPasteboardWriting {
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.noteDataHolder]
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.noteDataHolder]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .noteDataHolder {
            return try? PropertyListEncoder().encode(self)
        }
        return nil
    }

}
