//
//  RefNoteTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/03/2021.
//
// swiftlint:disable file_length

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
    var titleUnderLine = CALayer()
    var action: () -> Void

    private let titleLayer = CATextLayer()
    private let titleLayerXPosition: CGFloat = 22
    private let titleLayerYPosition: CGFloat = 2

    private var noteId: UUID
    private var noteTitle: String

    init(parent: Widget, noteId: UUID, actionTitle: String, action: @escaping () -> Void) throws {
        self.action = action
        self.noteId = noteId
        let title = BeamNote.titleForNoteId(noteId) ?? "<note not found>"
        self.noteTitle = title
        super.init(parent: parent)

        titleLayer.string = noteTitle.capitalized
        titleLayer.font = BeamFont.medium(size: 0).nsFont
        titleLayer.fontSize = 15
        titleLayer.foregroundColor = BeamColor.LinkedSection.title.cgColor

        titleUnderLine.frame = NSRect(x: 0, y: titleLayer.preferredFrameSize().height, width: titleLayer.preferredFrameSize().width, height: 2)
        titleUnderLine.backgroundColor = BeamColor.LinkedSection.title.cgColor
        titleUnderLine.isHidden = true
        titleLayer.addSublayer(titleUnderLine)

        cardTitleLayer = ButtonLayer("cardTitleLayer", titleLayer, activated: {[weak self] in
            guard let self = self, self.titleLayer.string as? String != nil else { return }

            self.editor.openCard(noteId, nil)
        })
        cardTitleLayer?.cursor = .pointingHand
        cardTitleLayer?.hovered = { [weak self] hover in
            self?.titleUnderLine.isHidden = !hover
        }

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        guard let cardTitleLayer = cardTitleLayer else { return }

        addLayer(cardTitleLayer)

        cardTitleLayer.frame = CGRect(origin: CGPoint(x: titleLayerXPosition, y: titleLayerYPosition), size: titleLayer.preferredFrameSize())
        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: (cardTitleLayer.frame.height / 2) - 7), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: open ? 24 : 44)
        computedIdealSize = contentsFrame.size

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    func makeLinksToNoteExplicit(forNote title: String) {
        for child in children {
            guard let breadcrumb = child as? BreadCrumb else { continue }
            breadcrumb.proxy.text.makeLinksToNoteExplicit(forNote: title)
        }
    }

    override var mainLayerName: String {
        "RefNoteTitle - \(noteTitle)"
    }
}
