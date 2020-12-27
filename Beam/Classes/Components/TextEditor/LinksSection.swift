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
    var open: Bool = true {
        didSet {
            updateVisibility(visible && open)
            updateChevron()
            invalidateLayout()
        }
    }

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
    let textLayer = CATextLayer()
    let chevronLayer = CALayer()

    init(editor: BeamTextEdit, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(editor: editor)
        // Append the linked references and unlinked references nodes
        textLayer.foregroundColor = NSColor.editorIconColor.cgColor
        textLayer.fontSize = 14
        let chevron = NSImage(named: "editor-arrow_right")
        let maskLayer = CALayer()
        maskLayer.contents = chevron
        chevronLayer.mask = maskLayer
        chevronLayer.backgroundColor = NSColor.editorIconColor.cgColor
        //chevronLayer.contents = chevron
        switch mode {
        case .links:
            textLayer.string = "\(note.linkedReferences.count) Links"
            linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] links in
                updateLinkedReferences()
                textLayer.string = "\(links.count) Links"
                updateLayerVisibility()
            }
        case .references:
            textLayer.string = "\(note.unlinkedReferences.count) References"
            linkedReferencesCancellable = note.$unlinkedReferences.sink { [unowned self] links in
                updateLinkedReferences()
                textLayer.string = "\(links.count) References"
                updateLayerVisibility()
            }
        }

        updateLinkedReferences()
        updateLayerVisibility()
        editor.layer?.addSublayer(layer)
        layer.addSublayer(textLayer)
        layer.addSublayer(chevronLayer)
        textLayer.frame = CGRect(origin: CGPoint(x: 25, y: 0), size: textLayer.preferredFrameSize())
        chevronLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: chevron?.size ?? CGSize(width: 20, height: 20))
        maskLayer.frame = chevronLayer.bounds
        updateChevron()
//        layer.backgroundColor = NSColor.red.withAlphaComponent(0.3).cgColor
//        offset = NSEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
//            print("new content scale: \(contentsScale)")
        }
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
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: linkedReferenceNodes.isEmpty ? 0 : 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    func updateLayerVisibility() {
        layer.isHidden = linkedReferenceNodes.isEmpty
    }

    override func updateChildrenLayout() {
        let childInset = 23
        var pos = NSPoint(x: CGFloat(childInset), y: self.contentsFrame.height)

        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - CGFloat(childInset)
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        print("LinkSection.mouseDown \(mouseInfo.position)")
        return super.mouseDown(mouseInfo: mouseInfo)
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        if contentsFrame.contains(mouseInfo.position) {
            open.toggle()
            return true
        }
        return super.mouseUp(mouseInfo: mouseInfo)
    }

    func updateChevron() {
        chevronLayer.setAffineTransform(CGAffineTransform(rotationAngle: open ? CGFloat.pi / 2 : 0))
    }
}
