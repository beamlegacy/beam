//
//  BreadCrumb.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/12/2020.
//

import Foundation
import AppKit

class BreadCrumb: Widget {

    // MARK: - Properties
    var crumbChain = [BeamElement]()
    var proxy: ProxyElement
    var crumbLayers = [CATextLayer]()
    var section: LinksSection
    var selectedCrumb: Int = 0

    let chevron = NSImage(named: "editor-arrow_right")
    let breadCrumbArrow = NSImage(named: "editor-breadcrumb_arrow")
    let chevronLayer = CALayer()
    let maskLayer = CALayer()
    let containerLayer = CALayer()
    let titleLayer = CATextLayer()
    let linkActionLayer = CATextLayer()

    let chevronXPosition: CGFloat = 0
    let titleLayerXPosition: CGFloat = 25
    let titleLayerYPosition: CGFloat = 10
    let limitCharacters: CGFloat = 100
    let breadCrumXPosition: CGFloat = 26
    let breadCrumYPosition: CGFloat = 26
    let spaceBreadcrumbIcon: CGFloat = 15

    var open: Bool = true {
        didSet {
            updateVisibility(visible && open)
            invalidateLayout()
            containerLayer.isHidden = !open
        }
    }

    var linkedReferenceNode: LinkedReferenceNode! {
        didSet {
            oldValue.delete()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            titleLayer.contentsScale = contentsScale
            linkActionLayer.contentsScale = contentsScale
            for l in crumbLayers {
                l.contentsScale = contentsScale
            }
        }
    }

    init(editor: BeamTextEdit, section: LinksSection, element: BeamElement) {
        self.section = section
        self.proxy = ProxyElement(for: element)
        super.init(editor: editor)

        self.crumbChain = computeCrumChain(from: element)

        guard let ref = editor.nodeFor(element) as? LinkedReferenceNode else { fatalError() }
        ref.parent = self
        self.linkedReferenceNode = ref

        // layer.backgroundColor = NSColor.blue.withAlphaComponent(0.2).cgColor
        editor.layer?.addSublayer(layer)

        guard let note = self.crumbChain.first as? BeamNote else { return }
        self.crumbChain.removeFirst()

        containerLayer.backgroundColor = NSColor.linkedContainerColor.cgColor
        containerLayer.opacity = 0.02
        containerLayer.cornerRadius = 10

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }))

        titleLayer.string = note.title.capitalized
        titleLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        titleLayer.fontSize = 17
        titleLayer.foregroundColor = NSColor.linkedTitleColor.cgColor

        linkActionLayer.string = "Link"
        linkActionLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkActionLayer.fontSize = 13
        linkActionLayer.foregroundColor = NSColor.linkedActionButtonColor.cgColor

        layer.addSublayer(containerLayer)
        layer.addSublayer(titleLayer)

        if section.mode == .references {
            layer.addSublayer(linkActionLayer)
        }

        titleLayer.frame = CGRect(origin: CGPoint(x: 25, y: titleLayerYPosition), size: titleLayer.preferredFrameSize())
        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: titleLayerYPosition), size: CGSize(width: 20, height: 20))

        updateCrumbLayers()

        if children != [linkedReferenceNode] {
            children = [linkedReferenceNode]
            invalidateLayout()
        }
    }

    func computeCrumChain(from element: BeamElement) -> [BeamElement] {
        var chain = [BeamElement]()
        var current: BeamElement? = element

        while let elem = current {
            chain.append(elem)
            current = elem.parent
        }

        return chain.reversed()
    }

    override func updateRendering() {
        updateCrumbLayers()

        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: open ? (crumbChain.count <= 1 ? 35 : 60) : 0)
        computedIdealSize = contentsFrame.size

        CATransaction.disableAnimations {
            let yPos = crumbChain.count <= 1 ? 38 : breadCrumYPosition + 9
            linkActionLayer.frame = CGRect(origin: CGPoint(x: availableWidth - linkActionLayer.frame.width, y: yPos), size: linkActionLayer.preferredFrameSize())
        }

        for c in children {
            computedIdealSize.height += c.idealSize.height

            CATransaction.disableAnimations {
                containerLayer.frame = NSRect(x: 0, y: titleLayer.frame.height + 10, width: (contentsFrame.width - linkActionLayer.frame.width) - 20, height: crumbChain.count <= 1 ? c.idealSize.height : c.idealSize.height + 20)
            }
        }

    }

    func updateCrumbLayers() {
        for l in crumbLayers {
            l.removeFromSuperlayer()
        }

        crumbLayers.removeAll()

        var x: CGFloat = 5
        var textFrame = CGSize.zero

        guard crumbChain.count > 1 else { return }

        for i in 0 ..< crumbChain.count {
            let newLayer = CATextLayer()
            let breadCrumbArrowLayer = CALayer()
            let breadCrumbMaskLayer = CALayer()

            newLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
            newLayer.fontSize = 10
            newLayer.foregroundColor = NSColor.linkedBreadcrumbColor.cgColor

            breadCrumbMaskLayer.contents = breadCrumbArrow
            breadCrumbArrowLayer.mask = breadCrumbMaskLayer
            breadCrumbArrowLayer.backgroundColor = NSColor.linkedChevronIconColor.cgColor

            if i != crumbChain.count - 1 {
                newLayer.addSublayer(breadCrumbArrowLayer)
            }

            layer.addSublayer(newLayer)
            crumbLayers.append(newLayer)

            let crumb = crumbChain[i]
            let note = crumb as? BeamNote
            let text: String = (note != nil ? (note?.title ?? "???") : crumb.text.text)

            newLayer.string = text.capitalized
            newLayer.truncationMode = .end
            newLayer.contentsScale = contentsScale

            textFrame = newLayer.preferredFrameSize()
            let textWidth = textFrame.width > limitCharacters ? limitCharacters : textFrame.width

            breadCrumbArrowLayer.frame = CGRect(origin: CGPoint(x: textWidth + 2, y: textFrame.height - 10.5), size: CGSize(width: 10, height: 10))
            breadCrumbMaskLayer.frame = breadCrumbArrowLayer.bounds

            newLayer.frame = CGRect(
                origin: CGPoint(x: x, y: textFrame.height + breadCrumYPosition),
                size: CGSize(width: textWidth, height: textFrame.height)
            )

            x += newLayer.bounds.width + spaceBreadcrumbIcon
        }

        selectedCrumb = crumbLayers.count
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return contentsFrame.contains(mouseInfo.position)
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        for i in 0..<crumbChain.count where !crumbLayers[i].isHidden {
            let crumb = crumbChain[i]
            let layer = crumbLayers[i]

            if layer.frame.contains(mouseInfo.position) {
                guard i != 0 else {
                    editor.openCard(crumbChain[0].note!.title)
                    return true
                }
                guard i != selectedCrumb else { return false }
                selectedCrumb = i
                updateCrumbLayersVisibility()
                guard let ref = editor.nodeFor(crumb) as? LinkedReferenceNode else { fatalError() }
                linkedReferenceNode.removeFromSuperlayer(recursive: true)
                ref.addLayerTo(layer: editor.layer!, recursive: true)
                linkedReferenceNode = ref
                linkedReferenceNode.unfold()
                children = [linkedReferenceNode]
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
