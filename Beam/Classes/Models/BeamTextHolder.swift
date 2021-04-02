//
//  BeamTextHolder.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 11/03/2021.
//

import Foundation
import BeamCore

extension NSPasteboard.PasteboardType {
    static let bTextHolder = NSPasteboard.PasteboardType("co.beamapp.macos.textHolder")
}

class BeamTextHolder: NSObject, Codable {

    var bText: BeamText

    init(bText: BeamText) {
        self.bText = bText
    }

    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let data = propertyList as? Data,
            let bTextHolder = try? PropertyListDecoder().decode(BeamTextHolder.self, from: data) else { return nil }
        self.init(bText: bTextHolder.bText)
    }
}

extension BeamTextHolder: NSPasteboardReading, NSPasteboardWriting {
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.bTextHolder]
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.bTextHolder]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .bTextHolder {
            return try? PropertyListEncoder().encode(self)
        }
        return nil
    }

}
