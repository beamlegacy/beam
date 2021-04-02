//
//  BeamElementHolder.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 10/03/2021.
//

import Foundation
import BeamCore

extension NSPasteboard.PasteboardType {
    static let elementHolder = NSPasteboard.PasteboardType("co.beamapp.macos.elementHolder")
}

class BeamElementHolder: NSObject, Codable {

    var elements: [BeamElement]

    init(elements: [BeamElement]) {
        self.elements = elements
    }

    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let data = propertyList as? Data,
            let elementHolder = try? PropertyListDecoder().decode(BeamElementHolder.self, from: data) else { return nil }
        self.init(elements: elementHolder.elements)
    }
}

extension BeamElementHolder: NSPasteboardReading, NSPasteboardWriting {
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.elementHolder]
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.elementHolder]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .elementHolder {
            return try? PropertyListEncoder().encode(self)
        }
        return nil
    }

}
