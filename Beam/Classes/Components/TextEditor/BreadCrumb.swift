//
//  BreadCrumb.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/12/2020.
//

import Foundation
import AppKit

class BreadCrumb: Widget {
    var crumbChain = [BeamElement]()
    var proxy: ProxyElement
    var linkedReferenceNode: LinkedReferenceNode!
    var crumbLayers = [CATextLayer]()

    init(editor: BeamTextEdit, section: LinksSection, element: BeamElement) {
        self.section = section
        self.proxy = ProxyElement(for: element)
        super.init(editor: editor)

        self.crumbChain = computeCrumChain(from: element)

        self.linkedReferenceNode = LinkedReferenceNode(editor: editor, parent: self, element: element)
        self.linkedReferenceNode.parent = self

//        layer.backgroundColor = NSColor.blue.withAlphaComponent(0.2).cgColor
        editor.layer?.addSublayer(layer)

        updateCrumbLayers()
        if children != [linkedReferenceNode] {
            children = [linkedReferenceNode]
            invalidateLayout()
        }
    }

    func computeCrumChain(from element: BeamElement) -> [BeamElement] {
        var chain = [BeamElement]()
        var p = element.parent

        while p != nil {
            chain.append(p!)
            p = p?.parent
        }

        return chain.reversed()
    }

    override func updateRendering() {
        updateCrumbLayers()

        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 25)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        for c in children {
            computedIdealSize.height += c.idealSize.height
        }
    }

    func updateCrumbLayers() {
        for l in crumbLayers {
            l.removeFromSuperlayer()
        }

        crumbLayers.removeAll()

        var x = CGFloat(0)
        for i in 0 ..< crumbChain.count {
            let newLayer = CATextLayer()
            newLayer.fontSize = 12
            newLayer.foregroundColor = NSColor.editorTextColor.cgColor
            layer.addSublayer(newLayer)
            crumbLayers.append(newLayer)

            let crumb = crumbChain[i]
            let note = crumb as? BeamNote
            let text: String = (note != nil ? (note?.title ?? "???") : crumb.text.text) + " / "
            newLayer.string = text
            newLayer.contentsScale = contentsScale
            newLayer.frame = CGRect(origin: CGPoint(x: x, y: 0), size: newLayer.preferredFrameSize())
//            newLayer.backgroundColor = NSColor.red.withAlphaComponent(0.2).cgColor
            x += newLayer.bounds.width + 10
        }

    }

    override var contentsScale: CGFloat {
        didSet {
            for l in crumbLayers {
                l.contentsScale = contentsScale
            }
        }
    }

    override func updateChildrenLayout() {
        let childInset = 23
        var pos = NSPoint(x: CGFloat(childInset), y: self.contentsFrame.height)

        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - CGFloat(childInset)
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }
    }

    var section: LinksSection
}
