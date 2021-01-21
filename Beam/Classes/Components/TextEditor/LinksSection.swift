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
    var linkedReferencesCancellable: Cancellable!
    var note: BeamNote

    let sectionLayer = CALayer()
    let sectionTitleLayer = CATextLayer()
    let separatorLayer = CALayer()
    let offsetY: CGFloat = 40

    var open: Bool = true {
        didSet {
            updateVisibility(visible && open)
            updateChevron()
            invalidateLayout()
        }
    }

    var linkedReferenceNodes = [BreadCrumb]() {
        didSet {
            invalidateLayout()
            children = linkedReferenceNodes
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            sectionTitleLayer.contentsScale = contentsScale
        }
    }

    init(editor: BeamTextEdit, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(editor: editor)

        setupUI()
        createChevron()
        setupSectionMode()
        updateLayerVisibility()

        editor.layer?.addSublayer(layer)
        layer.addSublayer(sectionLayer)
        layer.addSublayer(separatorLayer)

        setupLayerFrame()
    }

    func setupUI() {
        sectionTitleLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        sectionTitleLayer.fontSize = 15
        sectionTitleLayer.foregroundColor = NSColor.linkedSectionTitleColor.cgColor

        sectionLayer.addSublayer(sectionTitleLayer)
        sectionLayer.backgroundColor = NSColor.clear.cgColor

        separatorLayer.backgroundColor = NSColor.linkedSeparatorColor.withAlphaComponent(0.5).cgColor
    }

    func setupSectionMode() {
        switch mode {
        case .links:
            sectionTitleLayer.string = "\(note.linkedReferences.count) Links"
            linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] links in
                updateLinkedReferences()
                sectionTitleLayer.string = "\(links.count) Links"
                updateLayerVisibility()
            }
        case .references:
            sectionTitleLayer.string = "\(note.unlinkedReferences.count) References"
            linkedReferencesCancellable = note.$unlinkedReferences.sink { [unowned self] links in
                updateLinkedReferences()
                sectionTitleLayer.string = "\(links.count) References"
                updateLayerVisibility()
            }
        }
    }

    func setupLayerFrame() {
        sectionTitleLayer.frame = CGRect(origin: CGPoint(x: 25, y: 0), size: sectionTitleLayer.preferredFrameSize())
    }

    func createChevron() {
        let chevronLayer = ButtonLayer("chevron", Layer.icon(named: "editor-arrow_right", color: NSColor.linkedChevronIconColor))
        chevronLayer.activated = { [unowned self] in
            open.toggle()
        }

        addLayer(chevronLayer, into: sectionLayer)
        updateChevron()
    }

    func updateLinkedReferences() {
        let refs: [NoteReference] = {
            switch mode {
            case .links:
                return note.linkedReferences
            case .references:
                return note.unlinkedReferences
            }
        }()

        self.linkedReferenceNodes = refs.compactMap { noteReference -> BreadCrumb? in
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            return BreadCrumb(editor: editor, section: self, element: referencingElement)
        }

        selfVisible = !linkedReferenceNodes.isEmpty
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: linkedReferenceNodes.isEmpty ? 0 : 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width
        sectionLayer.frame = CGRect(x: 0, y: 0, width: availableWidth, height: 26)
        separatorLayer.frame = CGRect(x: 0, y: sectionLayer.frame.maxY, width: availableWidth, height: 2)

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    func updateLayerVisibility() {
        layer.isHidden = linkedReferenceNodes.isEmpty
    }

    func updateChevron() {
        layers["chevron"]?.layer.setAffineTransform(CGAffineTransform(rotationAngle: open ? CGFloat.pi / 2 : 0))
    }
}
