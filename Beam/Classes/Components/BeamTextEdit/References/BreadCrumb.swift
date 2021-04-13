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
    var selectedCrumb: Int = 0
    var container: Layer?
    var actionLinkLayer: Layer?

    var linkedReferenceNode: LinkedReferenceNode!

    override var open: Bool {
        didSet {
            containerLayer.isHidden = !open
        }
    }

    private var currentNote: BeamNote?
    private var currentLinkedRefNode: LinkedReferenceNode!
    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    private let containerLayer = CALayer()
    private let linkLayer = CATextLayer()

    private let maxBreadCrumbWidth: CGFloat = 100
    private let breadCrumbYPosition: CGFloat = 1
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
        containerLayer.opacity = 0.02
        containerLayer.cornerRadius = 10

        container = Layer(name: "containerLayer", layer: containerLayer, hovered: { [weak self] isHover in
            guard let self = self else { return }
            self.containerLayer.backgroundColor = isHover ? BeamColor.LinkedSection.container.cgColor : NSColor.clear.cgColor
        })

        linkLayer.string = "Link"
        linkLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkLayer.fontSize = 13
        linkLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor

        let actionLayer = ButtonLayer(
                "actionLinkLayer",
                linkLayer,
                activated: {[weak self] in
                    guard let self = self else { return }

                    self.updateReferenceSection(self.proxy.text.text)
                },
                hovered: { [weak self] isHover in
                    guard let self = self else { return }
                    self.linkLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                }
            )
        actionLayer.layer.isHidden = !isReference
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
        let startXPositionBreadcrumb: CGFloat = 25
        var position = CGPoint(x: startXPositionBreadcrumb, y: breadCrumbYPosition)

        for index in 0 ..< crumbChain.count - 1 {
            let crumb = crumbChain[index]
            let crumbLayer = crumbLayers[index]
            let arrowLayer = crumbArrowLayers[index]

            let note = crumb as? BeamNote
            let text: String = index == selectedCrumb ? "..." : note?.title ?? crumb.text.text

            crumbLayer.string = text.capitalized

            let textFrame = crumbLayer.preferredFrameSize()
            let textWidth = min(textFrame.width, maxBreadCrumbWidth)

            crumbLayer.frame = CGRect(
                origin: position,
                size: CGSize(width: textWidth, height: textFrame.height)
            )

            position.x += crumbLayer.bounds.width + spaceBreadcrumbIcon
            arrowLayer.frame = CGRect(origin: CGPoint(x: position.x, y: position.y + 1), size: arrowLayer.frame.size)
            position.x += arrowLayer.frame.width + spaceBreadcrumbIcon

            let show = index <= selectedCrumb
            crumbLayer.isHidden = !show
            arrowLayer.isHidden = !show

            arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: index == selectedCrumb ? CGFloat.pi / 2 : 0))
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

        crumblayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        crumblayer.fontSize = 10
        crumblayer.foregroundColor = BeamColor.LinkedSection.breadcrumb.cgColor

        addLayer(ButtonLayer("breadcrumb\(index)",
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

    func createBreadcrumbArrowLayer(index: Int) {
        let arrowlayer = Layer.icon(named: "editor-breadcrumb_arrow", color: BeamColor.LinkedSection.chevronIcon.nsColor)
        arrowlayer.bounds = CGRect(origin: .zero, size: CGSize(width: 10, height: 10))

        addLayer(ButtonLayer("breadcrumbArrowLayer\(index)",
                             arrowlayer,
                             activated: {[weak self] in
                                guard let self = self else { return }

                                self.selectCrumb(self.selectedCrumb == index ? self.crumbChain.count - 1 : index)
                             }
        ))
        crumbArrowLayers.append(arrowlayer)
    }

    func updateReferenceSection(_ text: String) {
        guard let rootNote = editor.note.note else { return }
        self.editor.showOrHidePersistentFormatter(isPresent: false)

        text.ranges(of: rootNote.title).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            self.proxy.text.makeInternalLink(start..<end)
        }

        let reference = BeamNoteReference(noteTitle: proxy.note!.title, elementID: proxy.proxy.id)
        rootNote.addReference(reference)
    }

    var showCrumbs: Bool {
        crumbChain.count > 1
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: showCrumbs ? 25 : 0)
        actionLinkLayer?.layer.isHidden = !open
        computedIdealSize = contentsFrame.size

        CATransaction.disableAnimations {
            if !showCrumbs {
                layers["actionLinkLayer"]?.layer.isHidden = true
                return
            }

            layers["actionLinkLayer"]?.frame = CGRect(
                origin: CGPoint(x: (availableWidth - linkLayer.frame.width) - 10, y: breadCrumbYPosition + 9),
                size: linkLayer.preferredFrameSize()
            )
        }

        if open {
            var childrenHeight = CGFloat(0)

            for c in children {
                childrenHeight += c.idealSize.height
            }

            computedIdealSize.height += childrenHeight

            CATransaction.disableAnimations {
                guard let container = container else { return }
                let containerHeight = childrenHeight - (showCrumbs ? 40 : 12)
                container.frame = NSRect(x: 0, y: 10, width: contentsFrame.width, height: containerHeight)
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

    override func nodeFor(_ element: BeamElement) -> TextNode? {
        return mapping[element]?.ref
    }

    override func nodeFor(_ element: BeamElement, withParent: Widget) -> TextNode {
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
    private var mapping: [BeamElement: WeakReference<TextNode>] = [:]
    private var deadNodes: [TextNode] = []

    func purgeDeadNodes() {
        guard !accessingMapping else { return }
        for dead in deadNodes {
            removeNode(dead)
        }
        deadNodes.removeAll()
    }

    override func removeNode(_ node: TextNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }
}
