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
    var crumbArrowLayers = [CALayer]()
    var section: LinksSection
    var selectedCrumb: Int = 0
    var container: Layer?
    var cardTitleLayer: Layer?
    var actionLinkLayer: Layer?

    let chevron = NSImage(named: "editor-arrow_right")
    let breadCrumbArrow = NSImage(named: "editor-breadcrumb_arrow")
    let chevronLayer = CALayer()
    let maskLayer = CALayer()
    let containerLayer = CALayer()
    let titleLayer = CATextLayer()
    let linkLayer = CATextLayer()

    let chevronXPosition: CGFloat = 0
    let titleLayerXPosition: CGFloat = 25
    let titleLayerYPosition: CGFloat = 10
    let limitCharacters: CGFloat = 100
    let breadCrumbXPosition: CGFloat = 26
    let breadCrumbYPosition: CGFloat = 26
    let spaceBreadcrumbIcon: CGFloat = 15

    override var open: Bool {
        didSet {
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
            for l in crumbLayers {
                l.contentsScale = contentsScale
            }
        }
    }

    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    init(editor: BeamTextEdit, section: LinksSection, element: BeamElement) {
        self.section = section
        self.proxy = ProxyElement(for: element)
        super.init(editor: editor)

        self.crumbChain = computeCrumbChain(from: element)

        guard let ref = editor.nodeFor(element) as? LinkedReferenceNode else { fatalError() }
        ref.parent = self
        self.linkedReferenceNode = ref

        editor.layer?.addSublayer(layer)

        guard let note = self.crumbChain.first as? BeamNote else { return }

        self.crumbChain.removeFirst()
        self.crumbChain.removeLast()

        setupLayers(with: note)
        updateCrumbLayers()

        if section.mode == .references && crumbChain.count <= 1 {
            ref.createLinkActionLayer()
            ref.didMakeInternalLink = {[unowned self] text in
                updateReferenceSection(text)
            }
        }

        if children != [linkedReferenceNode] {
            children = [linkedReferenceNode]
            invalidateLayout()
        }
    }

    func setupLayers(with note: BeamNote) {
        containerLayer.opacity = 0.02
        containerLayer.cornerRadius = 10

        container = Layer(name: "containerLayer", layer: containerLayer, hover: { [weak self] isHover in
            guard let self = self else { return }
            self.containerLayer.backgroundColor = isHover ? NSColor.linkedContainerColor.cgColor : NSColor.clear.cgColor
        })

        titleLayer.string = note.title.capitalized
        titleLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        titleLayer.fontSize = 17
        titleLayer.foregroundColor = NSColor.linkedTitleColor.cgColor

        cardTitleLayer = Layer(name: "cardTitleLayer", layer: titleLayer, down: {[weak self] _ in
            guard let self = self, let title = self.titleLayer.string as? String else { return false }
            self.editor.openCard(title)
            return true
        })
        createChevronLayer()

        if section.mode == .references {
            linkLayer.string = "Link"
            linkLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
            linkLayer.fontSize = 13
            linkLayer.foregroundColor = NSColor.linkedActionButtonColor.cgColor

            addLayer(Layer(
                    name: "actionLinkLayer",
                    layer: linkLayer,
                    down: {[weak self] _ in
                        guard let self = self else { return false }
                        self.proxy.text.makeInternalLink(0..<self.proxy.text.text.count)
                        self.updateReferenceSection(self.proxy.text.text)

                        return true
                    },
                    hover: { [weak self] (isHover) in
                        guard let self = self else { return }
                        self.linkLayer.foregroundColor = isHover ? NSColor.linkedActionButtonHoverColor.cgColor : NSColor.linkedActionButtonColor.cgColor
                    }
                ))
        }

        guard let container = container,
              let cardTitleLayer = cardTitleLayer else { return }

        addLayer(cardTitleLayer)
        addLayer(container)

        cardTitleLayer.frame = CGRect(origin: CGPoint(x: 25, y: titleLayerYPosition), size: titleLayer.preferredFrameSize())
        layers["chevron"]?.frame = CGRect(origin: CGPoint(x: 0, y: titleLayer.frame.height - 8), size: CGSize(width: 20, height: 20))
    }

    func createChevronLayer() {
        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
            layers["actionLinkLayer"]?.layer.isHidden = !value

            crumbLayers.enumerated().forEach { index, crumbLayer in
                crumbLayer.isHidden = !open
                crumbArrowLayers[index].isHidden = !open
            }
        }))
    }

    func createLayerWithMouseEvents(_ layer: CATextLayer, index: Int) {
        addLayer(Layer(
                name: "newLayer\(index)",
                layer: layer,
                down: { [weak self] _ in
                    guard let self = self,
                          let textValue = self.crumbLayers[index].string as? String else { return false }

                    if textValue == self.breadcrumbPlaceholder { return false }

                    self.selectedCrumb = index
                    self.updateCrumbLayersVisibility()

                    return true
                },
                hover: { isHover in
                    layer.foregroundColor = isHover ? NSColor.linkedBreadcrumbHoverColor.cgColor : NSColor.linkedBreadcrumbColor.cgColor
                }
            )
        )
    }

    func createBreadcrumbArrow(_ layer: CALayer, index: Int) {
        addLayer(Layer(
            name: "breadcrumbArrowLayer\(index)",
            layer: layer,
            down: {[weak self] _ in
                guard let self = self else { return false }

                self.selectedCrumb = self.crumbLayers.count
                self.updateCrumbLayersVisibility(by: index)

                return true
            }
        ))
    }

    func computeCrumbChain(from element: BeamElement) -> [BeamElement] {
        var chain = [BeamElement]()
        var current: BeamElement? = element

        while let elem = current {
            chain.append(elem)
            current = elem.parent
        }

        return chain.reversed()
    }

    func updateCrumbLayers() {
        for l in crumbLayers {
            l.removeFromSuperlayer()
        }

        crumbLayers.removeAll()

        var startXPositionBreadcrumb: CGFloat = 25
        var textFrame = CGSize.zero

        guard crumbChain.count > 1 else { return }

        for index in 0 ..< crumbChain.count {
            let newLayer = CATextLayer()
            let breadcrumbArrowLayer = CALayer()
            let breadcrumbMaskLayer = CALayer()

            newLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
            newLayer.fontSize = 10
            newLayer.foregroundColor = NSColor.linkedBreadcrumbColor.cgColor

            breadcrumbMaskLayer.contents = breadCrumbArrow
            breadcrumbArrowLayer.mask = breadcrumbMaskLayer
            breadcrumbArrowLayer.backgroundColor = NSColor.linkedChevronIconColor.cgColor

            if index != crumbChain.count - 1 {
                createBreadcrumbArrow(breadcrumbArrowLayer, index: index)
            }

            createLayerWithMouseEvents(newLayer, index: index)
            crumbArrowLayers.append(breadcrumbArrowLayer)
            crumbLayers.append(newLayer)

            let crumb = crumbChain[index]
            let note = crumb as? BeamNote
            let text: String = (note != nil ? (note?.title ?? "???") : crumb.text.text)

            newLayer.string = text.capitalized
            newLayer.truncationMode = .end
            newLayer.contentsScale = contentsScale

            textFrame = newLayer.preferredFrameSize()
            let textWidth = textFrame.width > limitCharacters ? limitCharacters : textFrame.width

            breadcrumbArrowLayer.frame = CGRect(origin: CGPoint(x: textWidth + startXPositionBreadcrumb + 2, y: textFrame.height + breadCrumbYPosition + 2), size: CGSize(width: 10, height: 10))
            breadcrumbMaskLayer.frame = breadcrumbArrowLayer.bounds

            guard let layer = layers["newLayer\(index)"] else { return }

            layer.frame = CGRect(
                origin: CGPoint(x: startXPositionBreadcrumb, y: textFrame.height + breadCrumbYPosition),
                size: CGSize(width: textWidth, height: textFrame.height)
            )

            startXPositionBreadcrumb += layer.bounds.width + spaceBreadcrumbIcon
        }

        selectedCrumb = crumbLayers.count
    }

    func updateReferenceSection(_ text: String) {
        print("make internal link: \(text)")
    }

    func updateCrumbLayersVisibility(by index: Int = 0) {
        for i in 0..<crumbLayers.count {
            crumbLayers[i].isHidden = selectedCrumb == 0 ? (i == selectedCrumb ? false : true) : (i < selectedCrumb ? false : true)
            crumbArrowLayers[i].isHidden = selectedCrumb == 0 ? (i == selectedCrumb ? false : true) : (i < selectedCrumb ? false : true)
            crumbArrowLayers[i].setAffineTransform(CGAffineTransform(rotationAngle: 0))
        }

        let selectedIndex = selectedCrumb == crumbLayers.count || selectedCrumb == 0 ? index : selectedCrumb - 1
        let textLayer = crumbLayers[selectedIndex]
        guard let textValue = textLayer.string as? String else { return }

        if selectedCrumb == 0 {
            firstBreadcrumbText = textValue
            textLayer.string = breadcrumbPlaceholder

            layers["breadcrumbArrowLayer\(selectedIndex)"]?.frame = CGRect(
                origin: CGPoint(x: 40, y: textLayer.preferredFrameSize().height + breadCrumbYPosition + 2),
                size: CGSize(width: 10, height: 10)
            )
        } else if textValue == breadcrumbPlaceholder {
            textLayer.string = firstBreadcrumbText

            layers["breadcrumbArrowLayer\(selectedIndex)"]?.frame = CGRect(
                origin: CGPoint(x: textLayer.preferredFrameSize().width + 25 + 2, y: textLayer.preferredFrameSize().height + breadCrumbYPosition + 2),
                size: CGSize(width: 10, height: 10)
            )
        }

        if selectedCrumb == 0 || textValue == breadcrumbPlaceholder || textValue == firstBreadcrumbText {
            layers["newLayer\(selectedIndex)"]?.frame = CGRect(
                origin: CGPoint(x: 25, y: textLayer.preferredFrameSize().height + breadCrumbYPosition),
                size: textLayer.preferredFrameSize()
            )
        }

        crumbArrowLayers[selectedIndex].setAffineTransform(selectedCrumb == crumbLayers.count ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: CGFloat.pi / 2))
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: open ? (crumbChain.count <= 1 ? 35 : 60) : 30)
        actionLinkLayer?.layer.isHidden = !open
        computedIdealSize = contentsFrame.size

        CATransaction.disableAnimations {
            if crumbChain.count <= 1 {
                layers["actionLinkLayer"]?.layer.isHidden = true
                return
            }

            layers["actionLinkLayer"]?.frame = CGRect(
                origin: CGPoint(x: (availableWidth - linkLayer.frame.width) - 10, y: breadCrumbYPosition + 9),
                size: linkLayer.preferredFrameSize()
            )
        }

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height

                CATransaction.disableAnimations {
                    guard let container = container else { return }
                    let containerHeight = crumbChain.count <= 1 ? c.idealSize.height - 12 : computedIdealSize.height - 40
                    container.frame = NSRect(x: 0, y: titleLayer.frame.height + 10, width: contentsFrame.width, height: containerHeight)
                }
            }
        }

    }

    /*override func mouseUp(mouseInfo: MouseInfo) -> Bool {
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
    }*/
}
