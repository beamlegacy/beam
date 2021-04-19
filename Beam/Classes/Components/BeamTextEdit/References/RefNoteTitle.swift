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

enum RefNoteTitleError: Error {
    case emptyReference
    case noteNotFound
    case elementNotFound
}

class RefNoteTitle: Widget {
    // MARK: - Properties
    var cardTitleLayer: Layer?
    var actionLinkLayer: Layer?
    var titleUnderLine = CALayer()
    var action: () -> Void
    var showActionButton: Bool = true {
        didSet {
            layers["actionLinkLayer"]?.layer.isHidden = !(open && showActionButton)
        }
    }

    private let titleLayer = CATextLayer()
    private let linkLayer = CATextLayer()

    private let titleLayerXPosition: CGFloat = 25
    private let titleLayerYPosition: CGFloat = 10

    private var noteTitle: String

    init(parent: Widget, noteTitle: String, actionTitle: String, action: @escaping () -> Void) throws {
        self.action = action
        self.noteTitle = noteTitle
        super.init(parent: parent)

        titleLayer.string = noteTitle.capitalized
        titleLayer.font = BeamFont.regular(size: 0).nsFont
        titleLayer.fontSize = 18
        titleLayer.foregroundColor = BeamColor.LinkedSection.title.cgColor

        titleUnderLine.frame = NSRect(x: 0, y: titleLayer.preferredFrameSize().height, width: titleLayer.preferredFrameSize().width, height: 2)
        titleUnderLine.backgroundColor = BeamColor.LinkedSection.title.cgColor
        titleUnderLine.isHidden = true
        titleLayer.addSublayer(titleUnderLine)

        cardTitleLayer = ButtonLayer("cardTitleLayer", titleLayer, activated: {[weak self] in
            guard let self = self, let title = self.titleLayer.string as? String else { return }

            self.editor.openCard(title)
        })
        cardTitleLayer?.cursor = .pointingHand
        cardTitleLayer?.hovered = { [weak self] hover in
            self?.titleUnderLine.isHidden = !hover
        }

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
            layers["actionLinkLayer"]?.layer.isHidden = !value
        }))

        linkLayer.string = actionTitle
        linkLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkLayer.fontSize = 13
        linkLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor

        let actionLayer = ButtonLayer(
                "actionLinkLayer",
                linkLayer,
                activated: {
                    action()
                },
                hovered: { [weak self] isHover in
                    guard let self = self else { return }
                    self.linkLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                }
            )
        addLayer(actionLayer)

        guard let cardTitleLayer = cardTitleLayer else { return }

        addLayer(cardTitleLayer)

        cardTitleLayer.frame = CGRect(origin: CGPoint(x: titleLayerXPosition, y: titleLayerYPosition), size: titleLayer.preferredFrameSize())
        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: titleLayer.frame.height - 8), size: CGSize(width: 20, height: 20))
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 35)
        actionLinkLayer?.layer.isHidden = !(open && showActionButton)
        computedIdealSize = contentsFrame.size

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }

    }

    override var mainLayerName: String {
        "RefNoteTitle - \(noteTitle)"
    }
}
