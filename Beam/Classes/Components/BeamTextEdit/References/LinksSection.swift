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
import os.signpost

extension BeamNote {
    var sortingDate: Date { type.journalDate ?? creationDate }
}

class LinksSection: Widget {
    var note: BeamNote

    let sectionTitleLayer = CATextLayer()
    let separatorLayer = CALayer()

    var titles: [UUID: RefNoteTitle] = [:]

    var openChildrenDefault: Bool { true }
    var openedOnce: Bool = false {
        didSet {
            guard openedOnce && !oldValue else { return }

            self.updateLinkedReferences(links: self.links)
        }
    }

    var sign: SignPostId!

    override var open: Bool {
        didSet {
            openedOnce = openedOnce || open
            self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: open ? 7 : 0, right: 0)
        }
    }

    // signposts names:
    enum Signs {
        static let updateLinkedReferences: StaticString = "LinksSection.updateLinkedReferences"
        static let updateLinkedReferencesEvaluateSource: StaticString = "LinksSection.updateLinkedReferencesEvaluateSource"
        static let firstInit: StaticString = "LinksSection.firstInit"
        static let setupUI: StaticString = "LinksSection.setupUI"
    }

    init(parent: Widget, note: BeamNote, availableWidth: CGFloat) {
        self.note = note
        super.init(parent: parent, availableWidth: availableWidth)
        self.sign = BeamTextEdit.signPost.createId(object: self)
        sign.begin(Signs.firstInit)

        setupUI(openChildren: openChildrenDefault)
        setupSectionMode()
        updateInitialHeading()
    }

    func setupUI(openChildren: Bool) {
        performLayerChanges {
            self.sign.begin(Signs.setupUI)
            defer { self.sign.end(Signs.setupUI) }

            let chevron = ChevronButton("disclosure", open: openChildren, changed: { [unowned self] value in
                self.open = value
            })
            chevron.setAccessibilityIdentifier("linksSection_arrow")
            self.addLayer(chevron)

            self.sectionTitleLayer.font = BeamFont.semibold(size: 0).nsFont
            self.sectionTitleLayer.fontSize = 12

            self.addLayer(ButtonLayer("sectionTitle", self.sectionTitleLayer, activated: { [weak self] _ in
                guard let self = self else { return }
                guard let chevron = self.layers["disclosure"] as? ChevronButton else { return }

                self.open.toggle()
                chevron.open = self.open
            }))
            self.layer.addSublayer(self.separatorLayer)
            self.childInset = 9

            self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: self.open ? 7 : 0, right: 0)
        }
    }

    var links: [BeamNoteReference] { note.links }

    func updateInitialHeading() {
        guard initialUpdate else { return } // making sure we didn't already update the heading
        let refs = note.links
        updateHeading(refs.count)
    }

    /// This method is doing the actual work of setting up the links section. It is used both by LinksSection and ReferencesSection
    final func doSetupSectionMode() {
        BeamData.shared.$lastIndexedElement
            .dropFirst()
            .filter({ [weak self] element in
                guard let self = self,
                      let element = element,
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

        if openChildrenDefault || openedOnce {
            self.updateLinkedReferences(links: self.links)
        }
    }

    /// This method is overriden in ReferencesSection to properly handle reference:
    func setupSectionMode() {
        doSetupSectionMode()
    }

    var currentReferences = [BeamNoteReference]()

    var sectionTypeName: StaticString { "LinksSection" }
    var initialUpdate = true

    func updateLinkedReferences(links: [BeamNoteReference]) {
        os_signpost(.begin, log: sign.log, name: Signs.updateLinkedReferences, signpostID: sign.id, "%{public}s", note.titleAndId)
        defer { sign.end(Signs.updateLinkedReferences) }

        let sectionName = String(describing: Self.self)
        Logger.shared.logInfo("\(sectionName).updateLinkedReferences[\(note.title)] \(links.count) incoming", category: .noteEditor)
        defer {
            if initialUpdate {
                sign.end(Signs.firstInit)
            }

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
            os_signpost(.begin, log: sign.log, name: Signs.updateLinkedReferencesEvaluateSource, signpostID: sign.id, "%{public}s / %{public}s", noteReference.noteID.uuidString, noteReference.elementID.uuidString)

            let noteID = noteReference.noteID
            guard let breadCrumb = root?.getBreadCrumb(for: noteReference) else {
                sign.end(Signs.updateLinkedReferencesEvaluateSource)
                continue
            }

            // Prepare title children:
            guard BeamNote.fetch(id: noteID) != nil,
                  let refTitleWidget = try? titles[noteID]
                    ?? newrefs[noteID]
                    ?? RefNoteTitle(parent: self, noteId: noteID, availableWidth: childAvailableWidth)
            else {
                sign.end(Signs.updateLinkedReferencesEvaluateSource)
                continue
            }
            newrefs[noteID] = refTitleWidget
            toRemove.remove(refTitleWidget)

            // now attach bread crumbs to the titles we just refreshed
            if shouldHandleReference(rootNote: note.title, rootNoteId: note.id, text: breadCrumb.proxy.text, proxy: breadCrumb.proxyNode as? ProxyTextNode) {
                refTitleWidget.addChild(breadCrumb)
                validRefs += 1
            } else {
                refTitleWidget.removeChild(breadCrumb)
            }
            sign.end(Signs.updateLinkedReferencesEvaluateSource)
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
        Logger.shared.logInfo("\(sectionName).updateLinkedReferences[\(note.title)] done: \(validRefs) element(s) in section", category: .noteEditor)
    }

    func sortChildren() {
        children.sort { left, right in
            guard let left = left.children.first as? BreadCrumb,
                  let right = right.children.first as? BreadCrumb,
                  let leftDate = left.proxy.proxy.note?.sortingDate,
                  let rightDate = right.proxy.proxy.note?.sortingDate
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
        performLayerChanges {
            self.sectionTitleLayer.string = "link".localizedStringWith(comment: "link section title", count)
        }
    }

    override var children: [Widget] {
        didSet {
            selfVisible = !children.isEmpty
            visible = selfVisible
            let _selfVisible = selfVisible
            performLayerChanges {
                self.sectionTitleLayer.isHidden = !_selfVisible
                self.separatorLayer.isHidden = !_selfVisible
            }
        }
    }

    func shouldHandleReference(rootNote: String, rootNoteId: UUID, text: BeamText, proxy: ProxyTextNode?) -> Bool {
        let linksToNote = text.hasLinkToNote(id: rootNoteId)
        let referencesToNote = text.hasReferenceToNote(titled: rootNote)

        let isChild = proxy?.allParents.contains(self) ?? false
        let isFocused = proxy?.isFocused ?? false
        let mayBeDanglingRef = isChild && isFocused && !linksToNote && !referencesToNote
        let result = linksToNote || mayBeDanglingRef

        Logger.shared.logInfo("LinksSection.shouldHandleReference to \(rootNote) - \(rootNoteId): \(result) [linksToNote.\(linksToNote) || Dangling.\(mayBeDanglingRef)] (referencesToNote.\(referencesToNote)) - text: \(text.text)", category: .noteEditor)
        return result
    }

    func setupLayerFrame() {
        let linkAllLayer = self.layers["linkAllLayer"]
        self.sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 26, y: 1),
            size: CGSize(
                width: linkAllLayer?.frame.minX ?? self.availableWidth,
                height: self.sectionTitleLayer.preferredFrameSize().height
            )
        )

        self.layers["disclosure"]?.frame = CGRect(origin: CGPoint(x: 0, y: self.sectionTitleLayer.preferredFrameSize().height / 2 - 8.5), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() -> CGFloat {
        return selfVisible ? 21 : 0
    }

    override func updateSubLayersLayout() {
        performLayerChanges {
            self.setupLayerFrame()
            self.separatorLayer.frame = CGRect(x: 0, y: self.sectionTitleLayer.frame.maxY + 4, width: self.availableWidth, height: 1)
        }
    }

    override func updateColors() {
        super.updateColors()

        sectionTitleLayer.foregroundColor = BeamColor.LinkedSection.sectionTitle.cgColor
        separatorLayer.backgroundColor = BeamColor.LinkedSection.separator.cgColor
    }

    override var mainLayerName: String {
        return "LinksSection"
    }
}
