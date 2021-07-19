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
    var note: BeamNote

    let sectionTitleLayer = CATextLayer()
    let separatorLayer = CALayer()
    let offsetY: CGFloat = 40

    var titles: [UUID: RefNoteTitle] = [:]

    var openChildrenDefault: Bool { true }

    init(parent: Widget, note: BeamNote) {
        self.note = note
        super.init(parent: parent)

        setupUI(openChildren: openChildrenDefault)
        setupSectionMode()
    }

    func setupUI(openChildren: Bool) {
        addLayer(ChevronButton("disclosure", open: openChildren, changed: { [unowned self] value in
            self.open = value
        }))

        sectionTitleLayer.font = BeamFont.semibold(size: 0).nsFont
        sectionTitleLayer.fontSize = 12
        sectionTitleLayer.foregroundColor = BeamColor.LinkedSection.sectionTitle.cgColor

        addLayer(ButtonLayer("sectionTitle", sectionTitleLayer, activated: {
            guard let chevron = self.layers["disclosure"] as? ChevronButton else { return }

            self.open.toggle()
            chevron.open = self.open
        }))

        separatorLayer.backgroundColor = BeamColor.LinkedSection.separator.cgColor
        self.layer.addSublayer(separatorLayer)
    }

    var links: [BeamNoteReference] { note.links }

    func setupSectionMode() {
        AppDelegate.main.data.$lastChangedElement
            .dropFirst()
            .filter({ element in
                guard let element = element,
                      let refNoteID = element.note?.id
                else { return false }
                let ref = BeamNoteReference(noteID: refNoteID, elementID: element.id)
                let alreadyPresent = self.currentReferences.contains(ref)
                let linked = element.text.hasLinkToNote(id: self.note.id)
                let referenced = element.text.hasReferenceToNote(titled: self.note.title)
                return alreadyPresent || linked || referenced
            })
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { _ in
                self.updateLinkedReferences(links: self.links)
            }.store(in: &scope)

        self.updateLinkedReferences(links: self.links)
    }

    var currentReferences = [BeamNoteReference]()

    var initialUpdate = true
    func updateLinkedReferences(links: [BeamNoteReference]) {
        defer {
            initialUpdate = false
        }

        // Mix existing references and new ones, make them unique in a set and let "shouldHandleReference" handle what should stay and what should go
        let allLinks = Set(links + currentReferences)
        currentReferences = links

        var validRefs = 0
        var newrefs = [UUID: RefNoteTitle]()
        var toRemove = Set<RefNoteTitle>(titles.values)

        for noteReference in allLinks {
            let noteID = noteReference.noteID
            guard let breadCrumb = root?.getBreadCrumb(for: noteReference) else { continue }

            // Prepare title children:
            guard let refTitleWidget = try? titles[noteID]
                    ?? newrefs[noteID]
                    ?? RefNoteTitle(parent: self, noteId: noteID, actionTitle: "Link", action: { self.linkAllReferencesFromNote(withId: noteID) })
            else { continue }
            newrefs[noteID] = refTitleWidget
            toRemove.remove(refTitleWidget)

            // now attach bread crumbs to the titles we just refreshed
            if shouldHandleReference(rootNote: note.title, rootNoteId: note.id, text: breadCrumb.proxy.text) {
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

        // Purge empty titles
        for child in children where child.children.isEmpty {
            removeChild(child)
        }

        updateHeading(validRefs)
    }

    func linkAllReferencesFromNote(withId noteId: UUID) {
        // TODO
    }

    override func updateChildrenLayout() {
        super.updateChildrenLayout()
        layout(children: children)
    }

    private func layout(children: [Widget]) {
        for child in children {
            child.layer.frame.origin = CGPoint(x: child.layer.frame.origin.x - 8, y: child.frameInDocument.origin.y - 5)
        }
    }

    func updateHeading(_ count: Int) {
        sectionTitleLayer.string = "link".localizedStringWith(comment: "link section title", count)
        selfVisible = !children.isEmpty
        visible = selfVisible
        sectionTitleLayer.isHidden = !selfVisible
        separatorLayer.isHidden = !selfVisible
    }

    func shouldHandleReference(rootNote: String, rootNoteId: UUID, text: BeamText) -> Bool {
        let linksToNote = text.hasLinkToNote(id: rootNoteId)
        let referencesToNote = text.hasReferenceToNote(titled: rootNote)

        // This is subtle: we don't want hide nodes that have just been edited so that they are not a link to this card anymore, so we make them disapear only if the became a reference to the curent card. This only happens after the initial update as the initial update should filter out anything that is not a link. It has the symetrical behaviour of ReferencesSection
        if initialUpdate {
            return linksToNote
        } else {
            return linksToNote || !referencesToNote
        }
    }

    var layerFrameXPad = CGFloat(25)
    func setupLayerFrame() {
        sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 22, y: 0),
            size: CGSize(
                width: availableWidth + layerFrameXPad,
                height: sectionTitleLayer.preferredFrameSize().height
            )
        )

        layers["disclosure"]?.frame = CGRect(origin: CGPoint(x: 0, y: sectionTitleLayer.preferredFrameSize().height / 2 - 9), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: selfVisible ? 30 : 0)

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
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 4, width: 560, height: 1)
        }
    }

    override var mainLayerName: String {
        return "LinkSection"
    }
}
