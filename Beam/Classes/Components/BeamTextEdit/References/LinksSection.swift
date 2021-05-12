//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine
import AppKit
import BeamCore

class LinksSection: Widget {
    enum Mode {
        case links
        case references
    }

    var mode: Mode
    var note: BeamNote
    var linkLayer: Layer?

    let sectionTitleLayer = CATextLayer()
    let linkActionLayer = CATextLayer()
    let separatorLayer = CALayer()
    let offsetY: CGFloat = 40

    var titles: [String: RefNoteTitle] = [:]

    override var open: Bool {
        didSet {
            linkLayer?.layer.isHidden = !open
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            sectionTitleLayer.contentsScale = contentsScale
            linkActionLayer.contentsScale = contentsScale
        }
    }

    init(parent: Widget, note: BeamNote, mode: Mode) {
        self.note = note
        self.mode = mode
        super.init(parent: parent)

        setupUI()
        setupSectionMode()
    }

    func setupUI() {
        addLayer(ChevronButton("disclosure", open: mode == .links, changed: { [unowned self] value in
            self.open = value
        }))

        sectionTitleLayer.font = BeamFont.medium(size: 0).nsFont
        sectionTitleLayer.fontSize = 12
        sectionTitleLayer.foregroundColor = BeamColor.LinkedSection.sectionTitle.cgColor

        addLayer(ButtonLayer("sectionTitle", sectionTitleLayer, activated: {
            guard let chevron = self.layers["disclosure"] as? ChevronButton else { return }

            self.open.toggle()
            self.editor.showOrHidePersistentFormatter(isPresent: false)
            chevron.open = self.open
        }))

        linkActionLayer.font = BeamFont.medium(size: 0).nsFont
        linkActionLayer.fontSize = 12
        linkActionLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkActionLayer.contentsScale = contentsScale
        linkActionLayer.alignmentMode = .center
        linkActionLayer.string = "Link All"

        separatorLayer.backgroundColor = BeamColor.Mercury.cgColor
        self.layer.addSublayer(separatorLayer)
    }

    func setupSectionMode() {
        updateLinkedReferences(links: note.references)

        AppDelegate.main.data.$lastChangedElement
            .filter({ element in
                guard let element = element,
                      let refNoteTitle = element.note?.title
                else { return false }
                let title = self.note.title
                let ref = BeamNoteReference(noteTitle: refNoteTitle, elementID: element.id)
                return self.currentReferences.contains(ref)
                    || element.text.hasLinkToNote(named: title)
                    || element.text.hasReferenceToNote(titled: title)
            })
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { _ in
                self.updateLinkedReferences(links: self.note.references)
            }.store(in: &scope)
        switch mode {
        case .references:
            createLinkAllLayer()
        default: break
        }
    }

    var currentReferences = [BeamNoteReference]()
    func updateLinkedReferences(links: [BeamNoteReference]) {
        currentReferences = links

        var validRefs = 0
        var newrefs = [String: RefNoteTitle]()
        var toRemove = Set<RefNoteTitle>(titles.values)

        for noteReference in links {
            let noteTitle = noteReference.noteTitle
            guard let breadCrumb = root?.getBreadCrumb(for: noteReference) else { continue }

            // Prepare title children:
            guard let refTitleWidget = try? titles[noteTitle] ?? RefNoteTitle(parent: self, noteTitle: noteTitle, actionTitle: "Link", action: {
                self.linkAllReferencesFromNote(named: noteTitle)
            }) else { continue }
            newrefs[noteTitle] = refTitleWidget
            toRemove.remove(refTitleWidget)

            // now attach bread crumbs to the titles we just refreshed
            if shouldHandleReference(rootNote: note.title, text: breadCrumb.proxy.text) {
                refTitleWidget.addChild(breadCrumb)
                validRefs += 1
            } else {
                refTitleWidget.removeChild(breadCrumb)
            }
        }

        titles = newrefs

        for refTitle in newrefs.values where !refTitle.children.isEmpty {
            addChild(refTitle)
        }

        for oldChild in toRemove {
            removeChild(oldChild)
        }

        updateHeading(validRefs)
    }

    func linkAllReferencesFromNote(named noteTitle: String) {
        // TODO
    }

    func updateHeading(_ count: Int) {
        switch mode {
        case .links:
            sectionTitleLayer.string = "link".localizedStringWith(comment: "link section title", count)
        case .references:
            sectionTitleLayer.string = "reference".localizedStringWith(comment: "reference section title", count)
        }
        selfVisible = !children.isEmpty
        visible = selfVisible
        sectionTitleLayer.isHidden = !selfVisible
        separatorLayer.isHidden = !selfVisible
    }

    func shouldHandleReference(rootNote: String, text: BeamText) -> Bool {
        let linksToNote = text.hasLinkToNote(named: rootNote)
        let referencesToNote = text.hasReferenceToNote(titled: rootNote)

        switch mode {
        case .links:
            return linksToNote
        case .references:
            return !linksToNote && referencesToNote
        }
    }

    func createLinkAllLayer() {
        let linkContentLayer = CALayer()
        linkContentLayer.addSublayer(linkActionLayer)

        linkLayer = LinkButtonLayer(
            "linkAllLayer",
            linkContentLayer,
            activated: { [weak self] in
                guard let self = self,
                      let rootNote = self.editor.note.note else { return }

                if let linkLayer = self.linkLayer, linkLayer.layer.isHidden { return }

                self.editor.showOrHidePersistentFormatter(isPresent: false)
                self.children.forEach { child in
                    guard let breadcrumb = child as? BreadCrumb else { return }
                    breadcrumb.proxy.text.makeLinkToNoteExplicit(forNote: rootNote.title)
                }
            }, hovered: {[weak self] isHover in
                guard let self = self else { return }

                self.linkActionLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
            })

        guard let linkLayer = linkLayer else { return }
        addLayer(linkLayer)
    }

    func setupLayerFrame() {
        sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 25, y: 0),
            size: CGSize(
                width: availableWidth - (linkLayer?.layer.frame.width ?? 0 + (mode == .references ? 30 : 25)),
                height: sectionTitleLayer.preferredFrameSize().height
            )
        )

        layers["disclosure"]?.frame = CGRect(origin: CGPoint(x: 0, y: sectionTitleLayer.preferredFrameSize().height - 15), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: -8, y: 8, width: availableWidth, height: selfVisible ? 30 : 0)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        if open && selfVisible {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    override func updateSubLayersLayout() {
        CATransaction.disableAnimations {
            setupLayerFrame()
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 14, width: 560, height: 1)

            guard let linkAllLayer = linkLayer else { return }
            linkAllLayer.frame = CGRect(origin: CGPoint(x: frame.width - linkAllLayer.frame.width / 2, y: 0), size: NSSize(width: 54, height: 21))

            let linkActionLayerFrameSize = linkActionLayer.preferredFrameSize()
            let linkActionLayerXPosition = linkAllLayer.bounds.width / 2 - linkActionLayerFrameSize.width / 2
            let linkActionLayerYPosition = linkAllLayer.bounds.height / 2 - linkActionLayerFrameSize.height / 2
            linkActionLayer.frame = CGRect(x: linkActionLayerXPosition, y: linkActionLayerYPosition,
                                     width: linkActionLayerFrameSize.width, height: linkActionLayerFrameSize.height)
        }
    }

    override var mainLayerName: String {
        return "LinkSection"
    }
}
