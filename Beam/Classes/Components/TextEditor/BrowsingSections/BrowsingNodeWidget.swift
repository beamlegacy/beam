//
//  BrowsingNodeWidget.swift
//  Beam
//
//  Created by Sebastien Metrot on 15/01/2021.
//

import Foundation
import Combine
import AppKit

class BrowsingNodeWidget: Widget {
    var recursive: Bool

    var browsingNode: BrowsingNode
    let textLayer = CATextLayer()

    func updateChildrenNodes() {
        guard recursive else {
            layers["chevron"]?.layer.isHidden = true
            return
        }
        self.children = browsingNode.children.map({ node -> BrowsingNodeWidget in
            BrowsingNodeWidget(editor: editor, browsingNode: node, recursive: false)
        })

        layers["chevron"]?.layer.isHidden = self.children.isEmpty
        invalidateLayout()
    }

    init(editor: BeamTextEdit, browsingNode: BrowsingNode, recursive: Bool) {
        self.recursive = recursive
        self.browsingNode = browsingNode

        super.init(editor: editor)

        // Append the linked references and unlinked references nodes
        textLayer.foregroundColor = NSColor.editorIconColor.cgColor
        textLayer.fontSize = 14

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        browsingNode.$children.sink { [weak self] _ in
            guard let self = self else { return }
            self.updateChildrenNodes()
        }.store(in: &scope)

        let link = LinkStore.linkFor(browsingNode.link)
        let linkText = link?.title ?? link?.url ?? "<???>"
        let linkScore = AppDelegate.main.data.scores.scoreCard(for: link?.url ?? "")
        let score = linkScore.score
        textLayer.string = "\(score) - \(linkText)"

        editor.layer?.addSublayer(layer)
        layer.addSublayer(textLayer)
        textLayer.frame = CGRect(origin: CGPoint(x: 25, y: 0), size: textLayer.preferredFrameSize())
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
        }
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = availableWidth

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }
}

class BrowsingLinkWidget: Widget {
    var link: UInt64
    var score: Float

    init(editor: BeamTextEdit, link: UInt64, score: Float) {
        self.link = link
        self.score = score
        super.init(editor: editor)

        let url = LinkStore.linkFor(link)?.url ?? "<???>"
        addLayer(Layer.text(named: "link", "\(score) - \(url)", color: NSColor.red))
        editor.layer?.addSublayer(layer)
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = availableWidth
    }
}
