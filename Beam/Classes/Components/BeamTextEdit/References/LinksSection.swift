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

    override var open: Bool {
        didSet {
            self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: open ? 5 : 0, right: 0)
        }
    }

    init(parent: Widget, note: BeamNote, availableWidth: CGFloat?) {
        self.note = note
        super.init(parent: parent, availableWidth: availableWidth)

        setupUI(openChildren: openChildrenDefault)
        setupSectionMode()
    }

    func setupUI(openChildren: Bool) {
        let chevron = ChevronButton("disclosure", open: openChildren, changed: { [unowned self] value in
            self.open = value
            guard let root = self.parent as? TextRoot else { return }
            root.editor?.hideInlineFormatter()
            root.cancelSelection(.current)
        })
        chevron.setAccessibilityIdentifier("linksSection_arrow")
        addLayer(chevron)

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
        childInset = 9
    }

    var links: [BeamNoteReference] { note.links }

    /// This method is doing the actual work of setting up the links section. It is used both by LinksSection and ReferencesSection
    final func doSetupSectionMode() {
        AppDelegate.main.data.$lastIndexedElement
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
            .sink { [weak self] _ in
                guard let self = self else { return }
                let updatedLinks = self.links
                self.updateLinkedReferences(links: updatedLinks)
            }.store(in: &scope)

        self.updateLinkedReferences(links: self.links)
    }

    /// This method is overriden in ReferencesSection to properly handle reference:
    func setupSectionMode() {
        doSetupSectionMode()
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

        // BeamNote by itself don't contain any text so there is no reason to count it as a reference:
        for noteReference in allLinks where noteReference.elementID != noteReference.noteID {
            let noteID = noteReference.noteID
            guard let breadCrumb = root?.getBreadCrumb(for: noteReference) else { break }

            // Prepare title children:
            guard let refTitleWidget = try? titles[noteID]
                    ?? newrefs[noteID]
                    ?? RefNoteTitle(parent: self, noteId: noteID, availableWidth: availableWidth - childInset)
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

        sortChildren()
    }

    func sortChildren() {
        children.sort { left, right in
            guard let left = left.children.first as? BreadCrumb,
                  let right = right.children.first as? BreadCrumb,
                  let leftDate = left.proxy.proxy.note?.updateDate,
                  let rightDate = right.proxy.proxy.note?.updateDate
            else {
                Logger.shared.logError("LinksSection - Trying to compared notes that have no date", category: .noteEditor)
                return false
            }

            return leftDate > rightDate
        }
    }

// TODO change what this code does with the new layout engine. Do we want to be able to offset children that way?
//    override func updateChildrenLayout() {
//        super.updateChildrenLayout()
//        layout(children: children)
//    }
//
//    private func layout(children: [Widget]) {
//        for child in children {
//            child.layer.frame.origin = CGPoint(x: child.layer.frame.origin.x - 8, y: child.frameInDocument.origin.y - 5)
//        }
//    }

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

    func setupLayerFrame() {
        let linkAllLayer = layers["linkAllLayer"]
        sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 22, y: 0),
            size: CGSize(
                width: linkAllLayer?.frame.minX ?? availableWidth,
                height: sectionTitleLayer.preferredFrameSize().height
            )
        )

        layers["disclosure"]?.frame = CGRect(origin: CGPoint(x: 0, y: sectionTitleLayer.preferredFrameSize().height / 2 - 9), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() -> CGFloat {
        return selfVisible ? 21 : 0
    }

    override func updateSubLayersLayout() {
        CATransaction.disableAnimations {
            setupLayerFrame()
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 4, width: availableWidth, height: 1)
        }
    }

    override var mainLayerName: String {
        return "LinkSection"
    }
}
