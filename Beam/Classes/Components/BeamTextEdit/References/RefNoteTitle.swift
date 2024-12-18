//
//  RefNoteTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/03/2021.
//

import Foundation
import AppKit
import Combine
import BeamCore

enum RefNoteTitleError: Error {
    case emptyReference
    case noteNotFound
    case elementNotFound
}

class RefNoteTitle: Widget {
    // MARK: - Properties
    var cardTitleLayer: Layer?

    private let titleLayer = CATextLayer()
    private let titleLayerXPosition: CGFloat = 22
    private let titleLayerYPosition: CGFloat = 3

    private var noteId: UUID
    private var noteTitle: String

    override var open: Bool {
        didSet {
            self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: open ? 5 : 2, right: 0)
        }
    }

    init(parent: Widget, noteId: UUID, availableWidth: CGFloat) throws {
        self.noteId = noteId
        let title = BeamNote.titleForNoteId(noteId) ?? "<note not found>"
        self.noteTitle = title
        super.init(parent: parent, availableWidth: availableWidth)

        updateText()

        cardTitleLayer = ButtonLayer("cardTitleLayer", titleLayer, activated: {[weak self] mouseInfo in
            guard let self = self else { return }
            if mouseInfo?.rightMouse == true {
                guard let note = BeamNote.fetch(id: noteId), let state = self.editor?.state else { return }
                BeamNote.showNoteContextualNSMenu(for: note, state: state, at: mouseInfo?.globalPosition ?? .zero, in: self.editor, sections: [.open])
            } else {
                let inSplitView = mouseInfo?.event.modifierFlags.contains(.command) ?? false
                self.editor?.openNote(noteId, nil, nil, inSplitView)
            }
        })

        cardTitleLayer?.cursor = .pointingHand
        cardTitleLayer?.hovered = { [weak self] hover in
            self?.updateTitleForHover(hover)
        }

        let chevron = ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        })
        chevron.setAccessibilityIdentifier("refNote_arrow")
        addLayer(chevron)

        guard let cardTitleLayer = cardTitleLayer else { return }

        addLayer(cardTitleLayer)

        titleLayer.isWrapped = true

        cardTitleLayer.frame = CGRect(origin: CGPoint(x: titleLayerXPosition, y: titleLayerYPosition), size: titleLayer.preferredFrameSize())
        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: 2), size: CGSize(width: 20, height: 20))
        childInset = 13
        self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: open ? 5 : 2, right: 0)
    }

    override func updateRendering() -> CGFloat {
        guard let cardTitleLayer = cardTitleLayer else { return 24 }
        return cardTitleLayer.layer.frame.height + 5
    }

    override func updateLayout() {
        super.updateLayout()
        guard let cardTitleLayer = cardTitleLayer, let text = titleLayer.string as? NSAttributedString else { return }
        let boundingRect = text.boundingRect(with: NSSize(width: contentsWidth - titleLayerXPosition, height: 0), options: [.usesLineFragmentOrigin])
        cardTitleLayer.layer.frame.size = boundingRect.size
        cardTitleLayer.frame.size = boundingRect.size
    }

    override func updateColors() {
        super.updateColors()

        performLayerChanges {
            self.updateText()
            self.updateTitleForHover(self.hover)
        }
    }

    private func updateTitleForHover(_ hover: Bool) {
        if let attributedString = (titleLayer.string as AnyObject).mutableCopy() as? NSMutableAttributedString {
            let underlineColor = hover ? BeamColor.LinkedSection.title.cgColor : BeamColor.Generic.transparent.cgColor
            attributedString.removeAttribute(.underlineColor, range: attributedString.wholeRange)
            attributedString.addAttributes([.underlineColor: underlineColor], range: attributedString.wholeRange)
            titleLayer.string = attributedString
        }
    }

    private func updateText() {
        titleLayer.string = NSAttributedString(string: noteTitle.capitalized, attributes: [
            .font: BeamFont.medium(size: 15).nsFont,
            .foregroundColor: BeamColor.LinkedSection.title.cgColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: BeamColor.Generic.transparent.cgColor
        ])
    }

    func makeLinksToNoteExplicit(forNote title: String) {
        for child in children {
            guard let breadcrumb = child as? BreadCrumb else { continue }
            breadcrumb.convertReferenceToLink()
        }
    }

    override var mainLayerName: String {
        "RefNoteTitle - \(noteTitle)"
    }

    // Modify AddChild so that children are always sorted
    override func addChild(_ child: Widget) {
        guard !children.contains(child) else { return }
        var newChildren = children
        newChildren.append(child)
        updateAddedChild(child: child)
        children = newChildren.sorted { left, right in
            guard let leftBC = left as? BreadCrumb,
                  let rightBC = right as? BreadCrumb,
                  let leftElementNode = leftBC.children.first as? ElementNode,
                  let rightElementNode = rightBC.children.first as? ElementNode
            else { return false }
            let leftElement = leftElementNode.displayedElement
            let rightElement = rightElementNode.displayedElement

            return leftElement.indexPath < rightElement.indexPath
        }
        updateChildrenVisibility()
    }

}
