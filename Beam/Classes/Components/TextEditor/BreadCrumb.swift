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
    var linkedReferenceNode: LinkedReferenceNode! {
        didSet {
            oldValue.delete()
        }
    }
    var crumbLayers = [CATextLayer]()
    var section: LinksSection
    var selectedCrumb: Int = 0

    init(editor: BeamTextEdit, section: LinksSection, element: BeamElement) {
        self.section = section
        self.proxy = ProxyElement(for: element)
        super.init(editor: editor)

        self.crumbChain = computeCrumChain(from: element)

        self.linkedReferenceNode = LinkedReferenceNode(editor: editor, parent: self, element: element)

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
        var p: BeamElement? = element

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

        selectedCrumb = crumbLayers.count
    }

    override var contentsScale: CGFloat {
        didSet {
            for l in crumbLayers {
                l.contentsScale = contentsScale
            }
        }
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return contentsFrame.contains(mouseInfo.position)
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        for i in 0..<crumbChain.count where !crumbLayers[i].isHidden {
            let crumb = crumbChain[i]
            let layer = crumbLayers[i]

            if layer.frame.contains(mouseInfo.position) {
                selectedCrumb = i
                updateCrumbLayersVisibility()
                linkedReferenceNode = LinkedReferenceNode(editor: editor, parent: self, element: crumb)
                linkedReferenceNode.unfold()
                invalidateLayout()
                children = [linkedReferenceNode]
                let scale = contentsScale
                contentsScale = scale
                invalidateLayout()

                return true
            }
        }

        return false
    }

    func updateCrumbLayersVisibility() {
        for i in 0..<crumbLayers.count {
            crumbLayers[i].opacity = i < selectedCrumb ? 1.0 : 0.5
        }
    }
}
