//
//  BrowsingSessionWidget.swift
//  Beam
//
//  Created by Sebastien Metrot on 15/01/2021.
//

import Foundation
import Combine
import AppKit

class BrowsingSection: Widget {
    var open: Bool = true {
        didSet {
            updateVisibility(visible && open)
            invalidateLayout()
        }
    }

    var sorted: Bool = true {
        didSet {
            updateChildrenNodes()
            invalidateLayout()
        }
    }
    var note: BeamNote
    let textLayer = CATextLayer()
    let chevronLayer = CALayer()

    var links: Set<UInt64> {
        note.browsingSessions.reduce(into: Set<UInt64>()) { result, tree in
            result = result.union(tree.links)
        }
    }

    var sortedLinks: [(UInt64, Float)] {
        links.map { id -> (UInt64, Float) in
            (id, AppDelegate.main.data.scores.scoreCard(for: id).score)
        }
        .sorted { left, right -> Bool in
            left.1 < right.1
        }
    }

    func updateChildrenNodes() {
        self.clear()
        if sorted {
            for link in sortedLinks.reversed() {
                addChild(BrowsingLinkWidget(editor: editor, link: link.0, score: link.1))
            }
        } else {
            for session in note.browsingSessions {
                addChild(BrowsingNodeWidget(editor: editor, browsingNode: session.root, recursive: true))
            }
        }
        layers["chevron"]?.layer.isHidden = self.children.isEmpty
        invalidateLayout()
    }

    init(editor: BeamTextEdit, note: BeamNote) {
        self.note = note

        super.init(editor: editor)

        // Append the linked references and unlinked references nodes
        textLayer.foregroundColor = NSColor.editorIconColor.cgColor
        textLayer.fontSize = 14

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        addLayer(ButtonLayer("sorted", Layer.text("sorted"), activated: { [unowned self] in
            self.sorted.toggle()
        }), origin: CGPoint(x: 25, y: 0))

        note.$browsingSessions.sink { [weak self] _ in
            guard let self = self else { return }
            self.updateChildrenNodes()
        }.store(in: &scope)

        textLayer.string = "Browsing sessions"

        updateLayerVisibility()
        editor.layer?.addSublayer(layer)
        layer.addSublayer(textLayer)
        // layer.addSublayer(chevronLayer)
        textLayer.frame = CGRect(origin: CGPoint(x: 100, y: 0), size: textLayer.preferredFrameSize())
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
        }
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: note.browsingSessions.isEmpty ? 0 : 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = availableWidth

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    func updateLayerVisibility() {
        layer.isHidden = note.browsingSessions.isEmpty
    }
}
