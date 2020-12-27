//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine
import AppKit

class LinksSection: Widget {
    enum Mode {
        case links
        case references
    }

    var mode: Mode

    var linkedReferenceNodes = [LinkedReferenceNode]() {
        didSet {
            invalidateLayout()
            children = linkedReferenceNodes
            for c in linkedReferenceNodes {
                c.parent = self
            }
        }
    }
//    var unlinkedReferenceNodes = [UnlinkedReferenceNode]()
    var linkedReferencesCancellable: Cancellable!
    var note: BeamNote

    init(editor: BeamTextEdit, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(editor: editor)
        // Append the linked references and unlinked references nodes
        switch mode {
        case .links:
//            text = BeamText(text: "Links")
            linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] _ in
                updateLinkedReferences()
            }
        case .references:
//            text = BeamText(text: "References")
            linkedReferencesCancellable = note.$unlinkedReferences.sink { [unowned self] _ in
                updateLinkedReferences()
            }
        }

        updateLinkedReferences()
        layer.backgroundColor = NSColor.red.withAlphaComponent(0.3).cgColor
        editor.layer?.addSublayer(layer)

//        offset = NSEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    }

    func updateLinkedReferences() {
        let
            refs: [NoteReference] = {
            switch mode {
            case .links:
                return note.linkedReferences
            case .references:
                return note.unlinkedReferences
            }
        }()

        self.linkedReferenceNodes = refs.compactMap { noteReference -> LinkedReferenceNode? in
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            return LinkedReferenceNode(editor: editor, section: self, element: referencingElement)
        }

        selfVisible = !linkedReferenceNodes.isEmpty
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 50)
    }

    override func setLayout(_ frame: NSRect) {
        super.setLayout(frame)
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return super.mouseDown(mouseInfo: mouseInfo)
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        return super.mouseUp(mouseInfo: mouseInfo)
    }
}
