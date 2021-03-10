//
//  TextEditorCommand.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 04/03/2021.
//

import Foundation

struct BeamElementInstance {
    var note: BeamNote
    var element: BeamElement
}

class TextEditorCommand: Command<TextRoot> {

    override init(name: String) {
        super.init(name: name)
    }

    func getElement(for noteName: String, and id: UUID) -> BeamElementInstance? {
        guard let note = BeamNote.fetch(DocumentManager(), title: noteName),
              let element = note.findElement(id) else { return nil }
        return BeamElementInstance(note: note, element: element)
    }

    func encode(element: BeamElement) -> Data? {
        var data: Data?
        do {
            let encoder = JSONEncoder()
            data = try encoder.encode(element)
        } catch {
            Logger.shared.logError("Can't encode BeamElement", category: .general)
        }
        return data
    }

    func decode(data: Data?) -> BeamElement? {
        guard let data = data else { return nil }
        var element: BeamElement?
        do {
            let decoder = JSONDecoder()
            element = try decoder.decode(BeamElement.self, from: data)
        } catch {
            Logger.shared.logError("Can't decode BeamElement data", category: .general)

        }
        return element
    }
}
