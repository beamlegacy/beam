//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine
import AppKit

class LinksSection: TextNode {
    enum Mode {
        case links
        case references
    }

    var mode: Mode

    var linkedReferenceNodes = [LinkedReferenceNode]() {
        didSet {
            invalidateLayout()
        }
    }
//    var unlinkedReferenceNodes = [UnlinkedReferenceNode]()
    var linkedReferencesCancellable: Cancellable!
    var note: BeamNote

    override var parent: TextNode? {
        return editor.rootNode
    }

    override var children: [TextNode] {
        return linkedReferenceNodes
    }

    override var root: TextRoot {
        return editor.rootNode
    }

    init(editor: BeamTextEdit, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(editor: editor, element: BeamElement())
        // Append the linked references and unlinked references nodes
        switch mode {
        case .links:
            text = BeamText(text: "Links")
            linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] _ in
                updateLinkedReferences()
            }
        case .references:
            text = BeamText(text: "References")
            linkedReferencesCancellable = note.$unlinkedReferences.sink { [unowned self] _ in
                updateLinkedReferences()
            }
        }

        readOnly = true
        updateLinkedReferences()
        editor.layer?.addSublayer(layer)
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

        self.linkedReferenceNodes = refs.map { noteReference -> LinkedReferenceNode in
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { fatalError() }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else {
                fatalError()
            }
            return LinkedReferenceNode(editor: editor, section: self, element: referencingElement)
        }

        selfVisible = !linkedReferenceNodes.isEmpty
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
