//
//  BrowsingNodeWidget.swift
//  Beam
//
//  Created by Sebastien Metrot on 15/01/2021.
//

import Foundation
import Combine
import AppKit
import BeamCore

class BrowsingNodeWidget: Widget {
    var recursive: Bool

    var browsingNode: BrowsingNode
    let textLayer = CATextLayer()

    func updateChildrenNodes(children: [BrowsingNode]) {
        guard recursive else {
            layers["chevron"]?.layer.isHidden = true
            return
        }
        self.children = children.map({ node -> BrowsingNodeWidget in
            BrowsingNodeWidget(parent: self, browsingNode: node, recursive: recursive, availableWidth: availableWidth - childInset)
        })

        layers["chevron"]?.layer.isHidden = self.children.isEmpty
        invalidateLayout()
    }

    init(parent: Widget, browsingNode: BrowsingNode, recursive: Bool, availableWidth: CGFloat?) {
        self.recursive = recursive
        self.browsingNode = browsingNode

        super.init(parent: parent, availableWidth: availableWidth)

        // Append the linked references and unlinked references nodes
        textLayer.foregroundColor = BeamColor.Editor.icon.cgColor
        textLayer.fontSize = 14

        let chevron = ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        })
        chevron.setAccessibilityIdentifier("browsingNode_arrow")
        addLayer(chevron)

        browsingNode.$children
            .receive(on: DispatchQueue.main)
            .sink { [weak self] children in
            guard let self = self else { return }
                self.updateChildrenNodes(children: children)
        }.store(in: &scope)

        let link = LinkStore.linkFor(browsingNode.link)
        let linkText = link?.title ?? link?.url ?? "<???>"
        let linkScore = browsingNode.score
        let score = linkScore.score
        textLayer.string = "\(score) - \(linkText)"

        layer.addSublayer(textLayer)
        textLayer.frame = CGRect(origin: CGPoint(x: 25, y: 0), size: textLayer.preferredFrameSize())
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
        }
    }

    override func updateRendering() -> CGFloat {
        30
    }
}

class BrowsingLinkWidget: Widget {
    var link: ScoredLink

    init(parent: Widget, link: ScoredLink, availableWidth: CGFloat?) {
        self.link = link
        super.init(parent: parent, availableWidth: availableWidth)

        let url = LinkStore.linkFor(link.link)?.url ?? "<???>"
        addLayer(Layer.text(named: "link", "\(link.score.score) - \(url)", color: NSColor.red))
    }

    override func updateRendering() -> CGFloat {
        30
    }

    override var mainLayerName: String {
        "BrowsingLinkWidget"
    }
}
