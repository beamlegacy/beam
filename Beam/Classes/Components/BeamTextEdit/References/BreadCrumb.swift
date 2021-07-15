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

    var proxyTextNode: ProxyTextNode!
    var hasLink: Bool {
        isLink ? isLink : proxyTextNode.childrenIsLink()
    }

    override var open: Bool {
        didSet {
            containerLayer.isHidden = !open
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            linkLayer.contentsScale = contentsScale
            containerLayer.contentsScale = contentsScale
        }
    }

    private var currentNote: BeamNote?
    private var currentLinkedRefNode: ProxyTextNode!
    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    private let containerLayer = CALayer()
    private let linkLayer = CATextLayer()

    private let maxBreadCrumbWidth: CGFloat = 100
    private let breadCrumbYPosition: CGFloat = 1
    private let spaceBreadcrumbIcon: CGFloat = 3
    private let containerPadding: CGFloat = 23
    private let containerLinkSize: CGFloat = 538
    private let containerRefSize: CGFloat = 492

    init(parent: Widget, element: BeamElement) {
        self.proxy = ProxyElement(for: element)
        super.init(parent: parent, nodeProvider: NodeProviderImpl(proxy: true))

        self.crumbChain = computeCrumbChain(from: element)

        guard let ref = nodeFor(element, withParent: self) as? ProxyTextNode else { fatalError() }
        ref.open = element.children.isEmpty // Yes, this is intentional
        self.proxyTextNode = ref
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
        updateLinkLayerState()
        addLayer(actionLayer)

        createCrumbLayers()
        guard let container = container else { return }
        addLayer(container)
    }

    override var parent: Widget? {
        didSet {
            updateLinkLayerState()
        }
    }

    func updateLinkLayerState() {
        actionLinkLayer?.layer.isHidden = isLink
        deepInvalidateRendering()
        invalidateLayout()
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
        guard let ref = nodeFor(crumb, withParent: self) as? ProxyTextNode else { return }

        currentLinkedRefNode = ref

        for i in index ..< crumbChain.count {
            let crumb = crumbChain[i]
            guard let ref = nodeFor(crumb, withParent: self) as? ProxyTextNode else { return }
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
            arrowLayer.frame = CGRect(origin: CGPoint(x: position.x, y: (textFrame.height / 2) - 3),
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

        text.ranges(of: rootNote.title).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            self.proxy.makeInternalLink(start..<end, createNoteIfNeeded: true)
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
            child.availableWidth = (hasLink ? containerLinkSize : containerRefSize) - child.offsetInRoot.x + child.childInset
            child.selectionLayerWidth = child.layer.frame.width + child.offsetInRoot.x + child.childInset
            child.layer.frame.origin = CGPoint(x: child.layer.frame.origin.x - 8, y: child.frameInDocument.origin.y - 16)
            layout(children: child.children)
        }
    }

    var actionLinkLayer: LinkButtonLayer? {
        layers["actionLinkLayer"] as? LinkButtonLayer
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 14, y: 0, width: availableWidth, height: showCrumbs ? 37 : 18)

        computedIdealSize = contentsFrame.size

        CATransaction.disableAnimations {
            let linkLayerFrameSize = linkLayer.preferredFrameSize()
            if let actionLinkLayer = actionLinkLayer {
                actionLinkLayer.frame = CGRect(
                    origin: CGPoint(x: availableWidth - linkLayerFrameSize.width / 2, y: -2),
                    size: NSSize(width: 36, height: 21)
                )
                let linkLayerXPosition = actionLinkLayer.bounds.width / 2 - linkLayerFrameSize.width / 2
                let linkLayerYPosition = actionLinkLayer.bounds.height / 2 - linkLayerFrameSize.height / 2
                linkLayer.frame = CGRect(x: linkLayerXPosition, y: linkLayerYPosition,
                                         width: linkLayerFrameSize.width, height: linkLayerFrameSize.height)
            }
        }

        if open {
            var childrenHeight = CGFloat(0)
            for c in children {
                childrenHeight += c.idealSize.height
            }

            computedIdealSize.height += childrenHeight
            if !showCrumbs {
                childrenHeight -= 25
            }
            CATransaction.disableAnimations {
                guard let container = container else { return }
                let containerWidth: CGFloat = hasLink ? containerLinkSize : containerRefSize
                container.frame = NSRect(x: 0, y: -2, width: containerWidth, height: childrenHeight + containerPadding)
            }
        }
    }

    override var mainLayerName: String {
        "BreadCrumb - \(proxy.id.uuidString) (from note \(proxy.note?.title ?? "???"))"
    }

    var isLink: Bool {
        proxyTextNode.isLink
    }

    var isReference: Bool {
        !isLink
    }
}
