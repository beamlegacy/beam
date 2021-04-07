//
//  BrowsingSessionWidget.swift
//  Beam
//
//  Created by Sebastien Metrot on 15/01/2021.
//

import Foundation
import Combine
import AppKit
import BeamCore

class BrowsingSection: Widget {
    var sorted: Bool = true {
        didSet {
            updateChildrenNodes(sessions: note.browsingSessions)
            invalidateLayout()
        }
    }
    var note: BeamNote
    let textLayer = CATextLayer()
    let chevronLayer = CALayer()

    func links(sessions: [BrowsingTree]) -> Set<ScoredLink> {
        sessions.reduce(into: Set<ScoredLink>()) { result, tree in
            result = result.union(tree.scoredLinks)
        }
    }

    func sortedLinks(sessions: [BrowsingTree]) -> [ScoredLink] {
        links(sessions: sessions).sorted { left, right -> Bool in
            left.score.score < right.score.score
        }
    }

    func updateChildrenNodes(sessions: [BrowsingTree]) {
        self.clear()

        for session in sessions {
            session.dump()
        }

        if sorted {
            for link in sortedLinks(sessions: sessions).reversed() {
                addChild(BrowsingLinkWidget(parent: self, link: link))
            }
        } else {
            for session in sessions {
                addChild(BrowsingNodeWidget(parent: self, browsingNode: session.root, recursive: true))
            }
        }
        layers["chevron"]?.layer.isHidden = self.children.isEmpty
        invalidateLayout()
    }

    init(parent: Widget, note: BeamNote) {
        self.note = note

        super.init(parent: parent)

        // Append the linked references and unlinked references nodes
        textLayer.foregroundColor = BeamColor.Editor.icon.cgColor
        textLayer.fontSize = 14

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        addLayer(ButtonLayer("sorted", Layer.text("sorted"), activated: { [unowned self] in
            self.sorted.toggle()
        }), origin: CGPoint(x: 25, y: 0))

        note.$browsingSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
            guard let self = self else { return }
                self.updateChildrenNodes(sessions: sessions)
        }.store(in: &scope)

        textLayer.string = "Browsing sessions"

        updateLayerVisibility()
        layer.addSublayer(textLayer)
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

    override var mainLayerName: String {
        "BrowsingSection"
    }
}
