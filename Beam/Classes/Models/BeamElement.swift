//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//

import Foundation
import Combine

// Editable Text Data:
public class BeamElement: Codable, Identifiable, Hashable, ObservableObject {
    @Published public private(set) var id = UUID() { didSet { change() } }
    @Published var text = BeamText() { didSet { change() } }
    @Published var open = true { didSet { change() } }
    public private(set) var children = [BeamElement]() { didSet { change() } }
    @Published var readOnly = false { didSet { change() } }
//    @Published var ast: Parser.Node? { didSet { change() } }
    @Published var score: Float = 0 { didSet { change() } }
    @Published var creationDate = Date() { didSet { change() } }
    @Published var updateDate = Date()

    var note: BeamNote? {
        return parent?.note
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case open
        case children
        case readOnly
        case ast
        case creationDate
        case updateDate
    }

    init() {
    }

    init(_ text: String) {
        self.text = BeamText(text: text, attributes: [])
    }

    init(_ text: BeamText) {
        self.text = text
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        do {
            text = try container.decode(BeamText.self, forKey: .text)
        } catch {
            let _text = try container.decode(String.self, forKey: .text)
            text = BeamText(text: _text, attributes: [])
        }
        open = try container.decode(Bool.self, forKey: .open)
        readOnly = try container.decode(Bool.self, forKey: .readOnly)
        if container.contains(.creationDate) {
            creationDate = try container.decode(Date.self, forKey: .creationDate)
            updateDate = try container.decode(Date.self, forKey: .updateDate)
        }

        if container.contains(.children) {
            children = try container.decode([BeamElement].self, forKey: .children)
            for child in children {
                child.parent = self
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(open, forKey: .open)
        try container.encode(readOnly, forKey: .readOnly)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(updateDate, forKey: .updateDate)
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
    }

    func clearChildren() {
        for c in children {
            c.parent = nil
        }
        children = []
    }

    func removeChild(_ child: BeamElement) {
        guard let index = children.firstIndex(where: { (e) -> Bool in
            e === child
        }) else { return }
        children.remove(at: index)
        child.parent = nil
    }

    func indexOfChild(_ child: BeamElement) -> Int? {
        return children.firstIndex(where: { (e) -> Bool in
            e === child
        })
    }

    func addChild(_ child: BeamElement) {
        insert(child, after: children.last) // append
    }

    func insert(_ child: BeamElement, after: BeamElement?) {
        if let oldParent = child.parent {
            oldParent.removeChild(child)
        }

        child.parent = self
        guard let after = after, let index = indexOfChild(after) else {
            children.insert(child, at: 0)
            return
        }

        children.insert(child, at: index + 1)
    }

    @Published var parent: BeamElement?

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    func connectUnlinkedNotes(_ thisNoteTitle: String, _ allNotes: [BeamNote]) {
        for note in allNotes {
            if text.text.contains(note.title) {
                note.addUnlinkedReference(NoteReference(noteName: thisNoteTitle, elementID: id))
            }
        }

        for c in children {
            c.connectUnlinkedNotes(thisNoteTitle, allNotes)
        }
    }

    @Published var changed = 0
    func change() {
        updateDate = Date()
        changed += 1

        parent?.childChanged()
    }

    func childChanged() {
        change()
        parent?.childChanged()
    }

    func findElement(_ id: UUID) -> BeamElement? {
        guard id != self.id else { return self }

        for c in children {
            if let result = c.findElement(id) {
                return result
            }
        }

        return nil
    }

    func detectLinkedNotes(_ documentManager: DocumentManager) {
        guard let note = note else { return }
        guard text.text.count > 2 else { return }

        for link in text.internalLinks {
            let linkTitle = link.string
            let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
            let reference = NoteReference(noteName: note.title, elementID: id)
            refnote.addLinkedReference(reference)
            refnote.save(documentManager: documentManager)
        }

        for c in children {
            c.detectLinkedNotes(documentManager)
        }
    }

}
