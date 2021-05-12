//
//  BreadCrumb.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/12/2020.
//
// swiftlint:disable file_length

import Foundation
import AppKit
import BeamCore

class BreadCrumb: Widget {

    // MARK: - Properties
    var crumbChain = [BeamElement]()
    var proxy: ProxyElement
    var crumbLayers = [CATextLayer]()
    var crumbArrowLayers = [CALayer]()
    var selectedCrumb: Int?
    var container: Layer?

    var linkedReferenceNode: LinkedReferenceNode!

    override var open: Bool {
        didSet {
            containerLayer.isHidden = !open
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            linkLayer.contentsScale = contentsScale
            containerLayer.contentsScale = contentsScale
            if let actionLinkLayer = layers["actionLinkLayer"] as? LinkButtonLayer {
                actionLinkLayer.set(contentsScale)
            }
        }
    }

    private var currentNote: BeamNote?
    private var currentLinkedRefNode: LinkedReferenceNode!
    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    private let containerLayer = CALayer()
    private let linkLayer = CATextLayer()

    private let maxBreadCrumbWidth: CGFloat = 100
    private let breadCrumbYPosition: CGFloat = 3
    private let spaceBreadcrumbIcon: CGFloat = 3

    init(parent: Widget, element: BeamElement) {
        self.proxy = ProxyElement(for: element)
        super.init(parent: parent)
        proxies[element] = WeakReference(proxy)

        self.crumbChain = computeCrumbChain(from: element)

        guard let ref = nodeFor(element, withParent: self) as? LinkedReferenceNode else { fatalError() }
        ref.open = element.children.isEmpty // Yes, this is intentional
        self.linkedReferenceNode = ref
        self.currentLinkedRefNode = ref

        guard let note = self.crumbChain.first as? BeamNote else { return }

        currentNote = note
        self.crumbChain.removeFirst()

        setupLayers(with: note)
        selectCrumb(crumbChain.count - 1)
    }

    func setupLayers(with note: BeamNote) {
        containerLayer.cornerRadius = 4
        containerLayer.backgroundColor = BeamColor.LinkedSection.container.cgColor
        container = Layer(name: "containerLayer", layer: containerLayer, hovered: { _ in })

        linkLayer.string = "Link"
        linkLayer.font = BeamFont.medium(size: 0).nsFont
        linkLayer.fontSize = 12
        linkLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkLayer.alignmentMode = .center

        let linkContentLayer = CALayer()
        linkContentLayer.frame = CGRect(
                origin: CGPoint(x: availableWidth, y: 0),
                size: NSSize(width: 36, height: 21))
        linkContentLayer.addSublayer(linkLayer)

        let actionLayer = LinkButtonLayer(
                "actionLinkLayer",
            linkContentLayer,
                activated: {[weak self] in
                    guard let self = self else { return }
                    self.updateReferenceSection(self.proxy.text.text)
                },
                hovered: { [weak self] isHover in
                    guard let self = self else { return }
                    self.linkLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                }
            )
        actionLayer.layer.isHidden = isLink
        addLayer(actionLayer)

        createCrumbLayers()
        guard let container = container else { return }
        addLayer(container)
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

    func createCrumbLayers() {
        guard crumbChain.count > 1 else { return }

        for index in 0 ..< crumbChain.count - 1 {
            createBreadcrumLayer(index: index)
            createBreadcrumbArrowLayer(index: index)
        }

        selectCrumb(crumbLayers.count)
    }

    func selectCrumb(_ index: Int) {
        selectedCrumb = index
        let crumb = crumbChain[index]
        guard let ref = nodeFor(crumb, withParent: self) as? LinkedReferenceNode else { return }

        currentLinkedRefNode = ref

        for i in index ..< crumbChain.count {
            let crumb = crumbChain[i]
            guard let ref = nodeFor(crumb, withParent: self) as? LinkedReferenceNode else { return }
            if crumbChain.last?.id != crumb.id {
                ref.unfold()
            }
        }

        children = [currentLinkedRefNode]

        layoutBreadCrumbs()
        invalidateLayout()
    }

    func layoutBreadCrumbs() {
        let startXPositionBreadcrumb: CGFloat = 10
        var position = CGPoint(x: startXPositionBreadcrumb, y: breadCrumbYPosition)

        for index in 0 ..< crumbChain.count - 1 {
            let crumb = crumbChain[index]
            let crumbLayer = crumbLayers[index]
            let arrowLayer = crumbArrowLayers[index]

            let note = crumb as? BeamNote
            let text: String = index == selectedCrumb ? breadcrumbPlaceholder : note?.title ?? crumb.text.text

            crumbLayer.string = text.capitalized

            let textFrame = crumbLayer.preferredFrameSize()
            let textWidth = min(textFrame.width, maxBreadCrumbWidth)

            crumbLayer.frame = CGRect(
                origin: position,
                size: CGSize(width: textWidth, height: textFrame.height)
            )

            position.x += crumbLayer.bounds.width + spaceBreadcrumbIcon
            arrowLayer.frame = CGRect(origin: CGPoint(x: position.x, y: position.y + breadCrumbYPosition),
                                      size: CGSize(width: 10, height: 10))
            position.x += arrowLayer.frame.width + spaceBreadcrumbIcon

            let show = index <= selectedCrumb ?? 0
            crumbLayer.isHidden = !show
            arrowLayer.isHidden = !show

            if let chevronLayer = layers[breadcrumbChevronLayerName(for: index)] as? ChevronButton {
                chevronLayer.open = index == selectedCrumb
            }
        }
    }

    func createBreadcrumLayer(index: Int) {
        let crumblayer = CATextLayer()

        let crumb = crumbChain[index]
        let note = crumb as? BeamNote
        let text: String = note?.title ?? crumb.text.text

        crumblayer.string = text.capitalized
        crumblayer.truncationMode = .end
        crumblayer.contentsScale = contentsScale

        crumblayer.font = BeamFont.medium(size: 0).nsFont
        crumblayer.fontSize = 12
        crumblayer.foregroundColor = BeamColor.LinkedSection.breadcrumb.cgColor

        addLayer(ButtonLayer(breadcrumbLayerName(for: index),
                             crumblayer,
                             activated: {[weak self] in
                                guard let self = self else { return }
                                self.selectCrumb(self.selectedCrumb == index ? self.crumbChain.count - 1 : index)
                             },
                             hovered: { isHover in
                                crumblayer.foregroundColor = isHover ? BeamColor.LinkedSection.breadcrumbHover.cgColor : BeamColor.LinkedSection.breadcrumb.cgColor
                             }
        ))

        crumbLayers.append(crumblayer)
    }

    private var breadcrumLayerNamePrefix: String = "breadcrumb"
    private func breadcrumbLayerName(for index: Int) -> String {
        return "\(breadcrumLayerNamePrefix)\(index)"
    }
    private var breadcrumbChrevronlayerNamePrefix: String = "breadcrumbArrowLayer"
    private func breadcrumbChevronLayerName(for index: Int) -> String {
        return "\(breadcrumbChrevronlayerNamePrefix)\(index)"
    }

    func createBreadcrumbArrowLayer(index: Int) {
        let chevron = ChevronButton(breadcrumbChevronLayerName(for: index), icon: "editor-breadcrumb_arrow", open: index == selectedCrumb, changed: { [unowned self] _ in
            self.selectCrumb(self.selectedCrumb == index ? self.crumbChain.count - 1 : index)
        })
        addLayer(chevron)
        crumbArrowLayers.append(chevron.layer)
    }

    func updateReferenceSection(_ text: String) {
        guard let rootNote = editor.note.note else { return }
        self.editor.showOrHidePersistentFormatter(isPresent: false)

        text.ranges(of: rootNote.title).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            self.proxy.text.makeInternalLink(start..<end)
        }
    }

    var showCrumbs: Bool {
        crumbChain.count > 1
    }

    override func updateChildrenLayout() {
        super.updateChildrenLayout()
        layout(children: children)
    }

    private func layout(children: [Widget]) {
        for child in children {
            child.layer.frame.origin = CGPoint(x: child.layer.frame.origin.x, y: child.frameInDocument.origin.y + 10)
            layout(children: child.children)
        }
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: -10, width: availableWidth, height: showCrumbs ? 25 : 0)

        computedIdealSize = contentsFrame.size

        CATransaction.disableAnimations {
            if let actionLinkLayer = layers["actionLinkLayer"] as? LinkButtonLayer {
                actionLinkLayer.frame = CGRect(
                    origin: CGPoint(x: availableWidth, y: 0),
                    size: NSSize(width: 36, height: 21)
                )
                let linkLayerFrameSize = linkLayer.preferredFrameSize()
                let linkLayerXPosition = actionLinkLayer.bounds.width / 2 - linkLayerFrameSize.width / 2
                let linkLayerYPosition = actionLinkLayer.bounds.height / 2 - linkLayerFrameSize.height / 2
                linkLayer.frame = CGRect(x: linkLayerXPosition, y: linkLayerYPosition,
                                         width: linkLayerFrameSize.width, height: linkLayerFrameSize.height)
            }
        }

        if open {
            var childrenHeight = CGFloat(0)
            let hasLink = isLink ? isLink : currentLinkedRefNode.childrenIsLink()
            for c in children {
                childrenHeight += c.idealSize.height
            }

            computedIdealSize.height += childrenHeight
            if !showCrumbs {
                childrenHeight -= 25
            }
            CATransaction.disableAnimations {
                guard let container = container else { return }
                let containerWidth: CGFloat = hasLink ? 538 : 492
                container.frame = NSRect(x: 0, y: 0, width: containerWidth, height: childrenHeight + 22)
            }
        }
    }

    override var mainLayerName: String {
        "BreadCrumb - \(proxy.id.uuidString) (from note \(proxy.note?.title ?? "???"))"
    }

    var isLink: Bool {
        currentLinkedRefNode.isLink
    }

    var isReference: Bool {
        !isLink
    }

    private var proxies: [BeamElement: WeakReference<ProxyElement>] = [:]
    override func proxyFor(_ element: BeamElement) -> ProxyElement? {
        assert(element as? ProxyElement == nil) // Don't create a proxy to a proxy

        if let proxy = proxies[element]?.ref {
            return proxy
        }
        let proxy = ProxyElement(for: element)
        proxies[element] = WeakReference(proxy)
        return proxy
    }

    override func nodeFor(_ element: BeamElement) -> ElementNode? {
        return mapping[element]?.ref
    }

    override func nodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode {
        if let node = mapping[element]?.ref {
            return node
        }

        // BreadCrumbs can't create TextNodes, only LinkedReferenceNodes
        let node: TextNode = LinkedReferenceNode(parent: withParent, element: element)

        accessingMapping = true
        mapping[element] = WeakReference(node)
        accessingMapping = false
        purgeDeadNodes()

        node.contentsScale = contentsScale

        return node
    }

    override func clearMapping() {
        mapping.removeAll()
        super.clearMapping()
    }

    private var accessingMapping = false
    private var mapping: [BeamElement: WeakReference<ElementNode>] = [:]
    private var deadNodes: [ElementNode] = []

    func purgeDeadNodes() {
        guard !accessingMapping else { return }
        for dead in deadNodes {
            removeNode(dead)
        }
        deadNodes.removeAll()
    }

    override func removeNode(_ node: ElementNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }
}
