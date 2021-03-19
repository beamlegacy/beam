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

        sectionTitleLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        sectionTitleLayer.fontSize = 15
        sectionTitleLayer.foregroundColor = NSColor.linkedSectionTitleColor.cgColor

        addLayer(ButtonLayer("sectionTitle", sectionTitleLayer, activated: {
            guard let chevron = self.layers["disclosure"] as? ChevronButton else { return }

            self.open.toggle()
            self.editor.showOrHidePersistentFormatter(isPresent: false)
            chevron.open = self.open
        }))

        linkActionLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkActionLayer.fontSize = 13
        linkActionLayer.foregroundColor = NSColor.linkedActionButtonColor.cgColor

        separatorLayer.backgroundColor = NSColor.linkedSeparatorColor.withAlphaComponent(0.5).cgColor
    }

    func setupSectionMode() {
        linkActionLayer.string = "Link All"
        linkedReferencesCancellable = note.$references
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] links in
                Logger.shared.logDebug("Update \(links.count) Links and References for note '\(note.title)'")
                updateLinkedReferences(links: links)
            }

        switch mode {
        case .references:
            createLinkAllLayer()
        default: break
        }
    }

    func updateLinkedReferences(links: [NoteReference]) {
        var validRefs = 0
        var newrefs = [String: RefNoteTitle]()
        var toRemove = Set<RefNoteTitle>(titles.values)

        for noteReference in links {
            let noteName = noteReference.noteName
            guard let breadCrumb = root?.getBreadCrumb(for: noteReference) else { continue }

            // Prepare title children:
            guard let refTitleWidget = try? titles[noteName] ?? RefNoteTitle(parent: self, noteName: noteName, actionTitle: "Link", action: {
                self.linkAllReferencesFromNote(named: noteName)
            }) else { continue }
            newrefs[noteName] = refTitleWidget
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

    func linkAllReferencesFromNote(named noteName: String) {
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
        let referencesToNote = text.hasReferenceToNote(named: rootNote)

        switch mode {
        case .links:
            return linksToNote
        case .references:
            return !linksToNote && referencesToNote
        }
    }

    func createLinkAllLayer() {
        linkLayer = ButtonLayer(
            "linkAllLayer",
            linkActionLayer,
            activated: { [weak self] in
                guard let self = self,
                      let rootNote = self.editor.note.note else { return }

                if let linkLayer = self.linkLayer, linkLayer.layer.isHidden { return }

                self.editor.showOrHidePersistentFormatter(isPresent: false)
                self.children.forEach { child in
                    guard let breadcrumb = child as? BreadCrumb else { return }
                    breadcrumb.proxy.text.makeLinkToNoteExplicit(forNote: rootNote.title)

                    let reference = NoteReference(noteName: breadcrumb.proxy.note!.title, elementID: breadcrumb.proxy.proxy.id)
                    self.note.addReference(reference)
                }
            }, hovered: {[weak self] isHover in
                guard let self = self else { return }

                self.linkActionLayer.foregroundColor = isHover ? NSColor.linkedActionButtonHoverColor.cgColor : NSColor.linkedActionButtonColor.cgColor
            })

        guard let linkLayer = linkLayer else { return }
        addLayer(linkLayer)
    }

    func setupLayerFrame() {
        sectionTitleLayer.frame = CGRect(
            origin: CGPoint(x: 25, y: 0),
            size: CGSize(
                width: availableWidth - (linkActionLayer.frame.width + (mode == .references ? 30 : 25)),
                height: sectionTitleLayer.preferredFrameSize().height
            )
        )

        layers["disclosure"]?.frame = CGRect(origin: CGPoint(x: 0, y: sectionTitleLayer.preferredFrameSize().height - 15), size: CGSize(width: 20, height: 20))
        linkActionLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: linkActionLayer.preferredFrameSize())
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
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 7, width: frame.width, height: 2)

            guard let linkLayer = linkLayer else { return }
            linkLayer.frame = CGRect(origin: CGPoint(x: frame.width - linkActionLayer.frame.width, y: 0), size: linkActionLayer.preferredFrameSize())
        }
    }

    override var mainLayerName: String {
        return "LinkSection"
    }
}
