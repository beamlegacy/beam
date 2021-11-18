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

    var proxyTextNode: ProxyTextNode?
    var sourceNote: BeamNote

    override var open: Bool {
        didSet {
            containerLayer.isHidden = !open
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            actionLayer?.contentsScale = contentsScale
            containerLayer.contentsScale = contentsScale
        }
    }

    private var currentNote: BeamNote?
    private var currentLinkedRefNode: ProxyTextNode?
    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    private let containerLayer = CALayer()
    private var actionLayer: ButtonLayer?
    private let linkLayer = CATextLayer()

    private let maxBreadCrumbWidth: CGFloat = 100
    private let breadCrumbYPosition: CGFloat = 1
    private let spaceBreadcrumbIcon: CGFloat = 3
    private var containerPadding: CGFloat = 8

    init(parent: Widget, sourceNote: BeamNote, element: BeamElement, availableWidth: CGFloat?) {
        self.sourceNote = sourceNote
        self.proxy = ProxyElement(for: element)
        super.init(parent: parent, nodeProvider: NodeProviderImpl(proxy: true), availableWidth: availableWidth)

        self.crumbChain = computeCrumbChain(from: element)

        if isInNodeProviderTree {
            let node = nodeFor(element, withParent: self)
            if let ref = node as? ProxyTextNode {
                ref.open = element.children.isEmpty // Yes, this is intentional
                self.proxyTextNode = ref
                self.currentLinkedRefNode = ref
            } else {
                Logger.shared.logError("Couldn't create a proxy text node for \(element) (node: \(node)", category: .noteEditor)
            }
        } else {
            Logger.shared.logError("Trying to init a breadCrumb on a dead branch of the document tree for \(element). Bailing out", category: .noteEditor)
        }

        guard let note = self.crumbChain.first as? BeamNote else { return }

        currentNote = note
        self.crumbChain.removeFirst()

        setupLayers(with: note)
        selectCrumb(crumbChain.count - 1)
        self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: crumbChain.count > 1 ? 1 : 2, right: 0)
        self.childrenPadding = NSEdgeInsets(top: 2, left: 7, bottom: 3 + containerPadding, right: 0)
    }

    func setupLayers(with note: BeamNote) {
        containerLayer.cornerRadius = 3
        containerLayer.backgroundColor = BeamColor.LinkedSection.container.cgColor
        container = Layer(name: "containerLayer", layer: containerLayer, hovered: { _ in })

        linkLayer.string = "Link"
        linkLayer.font = BeamFont.medium(size: 0).nsFont
        linkLayer.fontSize = 12
        linkLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkLayer.alignmentMode = .center

        let linkContentLayer = CALayer()
        linkContentLayer.frame = CGRect(
                origin: CGPoint(x: availableWidth, y: actionLinkLayerheight),
                size: NSSize(width: 36, height: 21))
        linkContentLayer.addSublayer(linkLayer)

        actionLayer = LinkButtonLayer(
                "actionLinkLayer",
            linkContentLayer,
                activated: {[weak self] in
                    guard let self = self else { return }
                    self.converReferenceToLink(self.proxy.text.text)
                },
                hovered: { [weak self] isHover in
                    guard let self = self else { return }
                    self.linkLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                }
            )
        updateLinkLayerState()
        guard let actionLayer = actionLayer else { return }
        addLayer(actionLayer)

        createCrumbLayers()
        guard let container = container else { return }
        addLayer(container)
    }

    override var parent: Widget? {
        didSet {
            guard parent != oldValue else { return }
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

        if let currentLinkedRefNode = currentLinkedRefNode {
            children = [currentLinkedRefNode]
        } else {
            children = []
        }

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
        let chevron = ChevronButton(breadcrumbChevronLayerName(for: index), icon: "editor-breadcrumb_right", open: index == selectedCrumb, changed: { [unowned self] _ in
            self.selectCrumb(self.selectedCrumb == index ? self.crumbChain.count - 1 : index)
        })
        addLayer(chevron)
        chevron.setAccessibilityIdentifier("breadcrumb_arrow")
        crumbArrowLayers.append(chevron.layer)
    }

    func converReferenceToLink(_ text: String) {
        guard let rootNote = editor?.note.note else { return }

        text.ranges(of: rootNote.title, options: .caseInsensitive).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            self.proxy.makeInternalLink(start..<end)
        }
    }

    var showCrumbs: Bool {
        crumbChain.count > 1
    }

    var actionLinkLayer: LinkButtonLayer? {
        layers["actionLinkLayer"] as? LinkButtonLayer
    }

    var crumbsHeight: CGFloat { showCrumbs ? 21 : 1 }
    override func updateRendering() -> CGFloat {
        return crumbsHeight
    }

    var actionLinkLayerheight: CGFloat { crumbsHeight + self.contentsPadding.bottom - 1 }
    override func updateLayout() {
        super.updateLayout()
        CATransaction.disableAnimations {
            let linkLayerFrameSize = linkLayer.preferredFrameSize()
            if let actionLinkLayer = actionLinkLayer {
                actionLinkLayer.frame = CGRect(
                    origin: CGPoint(x: availableWidth - 36 - 10, y: actionLinkLayerheight),
                    size: NSSize(width: 36, height: 21)
                )
                let linkLayerXPosition = actionLinkLayer.bounds.width / 2 - linkLayerFrameSize.width / 2
                let linkLayerYPosition = actionLinkLayer.bounds.height / 2 - linkLayerFrameSize.height / 2
                linkLayer.frame = CGRect(x: linkLayerXPosition, y: linkLayerYPosition,
                                         width: linkLayerFrameSize.width, height: linkLayerFrameSize.height)
            }
        }

        if open {
            let childrenHeight = childrenIdealSize.size.height + crumbsHeight - childrenPadding.bottom - childrenPadding.top - contentsPadding.bottom - contentsPadding.top
            CATransaction.disableAnimations {
                guard let container = container else { return }
                container.frame = NSRect(x: 0, y: -2, width: availableWidth + containerPadding, height: childrenHeight + containerPadding)
            }
        }
    }

    override var mainLayerName: String {
        "BreadCrumb - \(proxy.id.uuidString) (from note \(proxy.note?.title ?? "???"))"
    }

    var isLink: Bool {
        proxyTextNode?.isLink ?? false
    }

    var isReference: Bool {
        !isLink
    }
}
