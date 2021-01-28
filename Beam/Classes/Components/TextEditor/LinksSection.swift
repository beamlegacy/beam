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
    var linkLayer: Layer?

    let sectionTitleLayer = CATextLayer()
    let linkActionLayer = CATextLayer()
    let separatorLayer = CALayer()
    let offsetY: CGFloat = 40

    override var open: Bool {
        didSet {
            linkLayer?.layer.isHidden = !open
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
            linkActionLayer.contentsScale = contentsScale
        }
    }

    init(editor: BeamTextEdit, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(editor: editor)

        setupUI()
        setupSectionMode()
        updateLayerVisibility()

        editor.layer?.addSublayer(layer)
        layer.addSublayer(sectionTitleLayer)
        layer.addSublayer(separatorLayer)
    }

    func setupUI() {
        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        sectionTitleLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        sectionTitleLayer.fontSize = 15
        sectionTitleLayer.foregroundColor = NSColor.linkedSectionTitleColor.cgColor

        addLayer(ButtonLayer("sectionTitle", sectionTitleLayer, activated: {
            self.open.toggle()
            guard let chevron = self.layers["chevron"] as? ChevronButton else { return }
            chevron.open = self.open
        }))

        linkActionLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkActionLayer.fontSize = 13
        linkActionLayer.foregroundColor = NSColor.linkedActionButtonColor.cgColor

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
            linkActionLayer.string = "Link All"
            sectionTitleLayer.string = "\(note.unlinkedReferences.count) References"
            linkedReferencesCancellable = note.$unlinkedReferences.sink { [unowned self] links in
                updateLinkedReferences()
                sectionTitleLayer.string = "\(links.count) References"
                updateLayerVisibility()
            }

            linkLayer = Layer(
                name: "linkAllLayer",
                layer: linkActionLayer,
                down: { [weak self] _ in
                    guard let self = self else { return false }
                    if let linkLayer = self.linkLayer,
                       linkLayer.layer.isHidden { return false }

                    self.linkedReferenceNodes.forEach { breadCrumb in
                        // breadCrumb.proxy.text.makeInternalLink(0..<breadCrumb.proxy.text.text.count)
                        print("Link All: \(breadCrumb.proxy.text.text)")
                    }
                    return true
                }, hover: {[weak self] isHover in
                    guard let self = self else { return }

                    self.linkActionLayer.foregroundColor = isHover ? NSColor.linkedActionButtonHoverColor.cgColor : NSColor.linkedActionButtonColor.cgColor
                })

            guard let linkLayer = linkLayer else { return }
            addLayer(linkLayer)
        }
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

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    override func updateSubLayersLayout() {
        CATransaction.disableAnimations {
            setupLayerFrame()
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 7, width: frame.width, height: 2)

            guard let linkLayer = linkLayer else { return }
            linkLayer.frame = CGRect(origin: CGPoint(x: frame.width - linkActionLayer.frame.width, y: 0), size: linkActionLayer.preferredFrameSize())
        }
    }

    func setupLayerFrame() {
        sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 25, y: 0),
            size: CGSize(
                width: availableWidth - (linkActionLayer.frame.width + (mode == .references ? 30 : 25)),
                height: sectionTitleLayer.preferredFrameSize().height
            )
        )

        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: sectionTitleLayer.preferredFrameSize().height - 15), size: CGSize(width: 20, height: 20))
        linkActionLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: linkActionLayer.preferredFrameSize())
    }

    func updateLayerVisibility() {
        layer.isHidden = linkedReferenceNodes.isEmpty
    }
}
