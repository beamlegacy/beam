//
//  BreadCrumb.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/12/2020.
//

import Foundation
import AppKit
import BeamCore

class BreadCrumb: Widget, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    // MARK: - Properties
    var crumbChain = [BeamElement]()
    var proxy: ProxyElement
    var crumbLayers = [CATextLayer]()
    var crumbArrowLayers = [CALayer]()
    var selectedCrumb: Int?
    var container: Layer?

    var proxyNode: ProxyNode?
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
    private var currentLinkedRefNode: ProxyNode?
    private var firstBreadcrumbText = ""
    private var breadcrumbPlaceholder = "..."

    private let containerLayer = CALayer()
    private var actionLayer: ButtonLayer?
    private let linkLayer = CATextLayer()

    private let maxBreadCrumbWidth: CGFloat = 100
    private let breadCrumbYPosition: CGFloat = 1
    private let spaceBreadcrumbIcon: CGFloat = 3
    private var containerPadding: CGFloat = 4

    init(parent: Widget, sourceNote: BeamNote, element: BeamElement, availableWidth: CGFloat) {
        self.sourceNote = sourceNote
        self.proxy = ProxyElement(for: element)
        super.init(parent: parent, nodeProvider: NodeProviderImpl(proxy: true), availableWidth: availableWidth)

        crumbChain = computeCrumbChain(from: element)

        if isInNodeProviderTree {
            let node = nodeFor(element, withParent: self)
            if let ref = node as? ProxyNode {
                ref.open = element.children.isEmpty // Yes, this is intentional
                proxyNode = ref
                currentLinkedRefNode = ref
            } else {
                Logger.shared.logError("Couldn't create a proxy text node for \(element) (node: \(node)", category: .noteEditor)
            }
        } else {
            Logger.shared.logError("Trying to init a breadCrumb on a dead branch of the document tree for \(element). Bailing out", category: .noteEditor)
        }

        guard let note = crumbChain.first as? BeamNote else { return }

        currentNote = note
        crumbChain.removeFirst()

        setupLayers(with: note)
        selectCrumb(crumbChain.count - 1)
        padding = NSEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: crumbChain.count > 1 ? 0 : 2, right: 0)
        childrenPadding = NSEdgeInsets(top: 0, left: 7, bottom: 3, right: 0)

        proxy.proxy.treeChanged.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.update()
        }.store(in: &scope)
        assert(editor != nil)
    }

    func setupLayers(with note: BeamNote) {
        performLayerChanges {
            self.containerLayer.cornerRadius = 3
            self.container = Layer(name: "containerLayer", layer: self.containerLayer, hovered: { _ in })

            self.linkLayer.string = "Link"
            self.linkLayer.font = BeamFont.medium(size: 0).nsFont
            self.linkLayer.fontSize = 12
            self.linkLayer.alignmentMode = .center

            let linkContentLayer = CALayer()
            linkContentLayer.frame = CGRect(
                origin: CGPoint(x: self.availableWidth, y: self.actionLinkLayerheight),
                size: NSSize(width: 36, height: 21))
            linkContentLayer.addSublayer(self.linkLayer)

            self.actionLayer = LinkButtonLayer(
                "actionLinkLayer",
                linkContentLayer,
                activated: {[weak self] _ in
                    guard let self = self else { return }
                    self.convertReferenceToLink()
                },
                hovered: { [weak self] isHover in
                    guard let self = self else { return }
                    self.linkLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                }
            )
            self.updateLinkLayerState()
            guard let actionLayer = self.actionLayer else { return }
            actionLayer.layer.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
            actionLayer.setAccessibilityIdentifier("link-reference-button")
            self.addLayer(actionLayer)

            self.createCrumbLayers()
        }
        guard let container = self.container else { return }
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

    func update() {
        crumbChain.removeAll()
        updateCrumbchain()
        resetCrumbLayers()
        createCrumbLayers()
        invalidateLayout()
    }

    func resetCrumbLayers() {
        for i in crumbLayers.indices {
            removeLayer(breadcrumbLayerName(for: i))
            removeLayer(breadcrumbChevronLayerName(for: i))
        }

        crumbLayers = []
        crumbArrowLayers = []
    }

    func updateCrumbchain() {
        crumbChain = computeCrumbChain(from: proxy.proxy)
        crumbChain.removeFirst()
    }

    func createCrumbLayers() {
        guard crumbChain.count > 1 else { return }

        for index in 0 ..< crumbChain.count - 1 {
            createBreadcrumLayer(index: index)
            createBreadcrumbArrowLayer(index: index)
        }

        selectCrumb(crumbChain.count - 1)
    }

    func selectCrumb(_ index: Int) {
        selectedCrumb = index
        let crumb = crumbChain[index]
        guard let ref = proxyNodeFor(crumb, withParent: self) as? ProxyNode else { return }

        currentLinkedRefNode = ref

        for i in index ..< crumbChain.count {
            let crumb = crumbChain[i]
            guard let ref = proxyNodeFor(crumb, withParent: self) as? ProxyNode else { return }
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

        for index in 0 ..< crumbLayers.count {
            let crumb = crumbChain[index]
            let crumbLayer = crumbLayers[index]
            let arrowLayer = crumbArrowLayers[index]

            let text: String = index == selectedCrumb ? breadcrumbPlaceholder : crumbTextFor(element: crumb)

            crumbLayer.string = text

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

    func crumbTextFor(element: BeamElement) -> String {
        if element.kind.isMedia {
            switch element.kind {
            case let .image(_, origin: data, displayInfos: _):
                return data?.title ?? "img"
            case let .embed(url, origin: data, displayInfos: _):
                return data?.title ?? url.hostname ?? "embed"
            default:
                return "media"
            }
        }

        let note = element as? BeamNote
        let text = note?.title ?? element.text.text
        return text.isEmpty ? "empty" : text.capitalized
    }

    func createBreadcrumLayer(index: Int) {
        let crumblayer = CATextLayer()

        let crumb = crumbChain[index]
        let text: String = crumbTextFor(element: crumb)

        crumblayer.string = text
        crumblayer.truncationMode = .end
        crumblayer.contentsScale = contentsScale

        crumblayer.font = BeamFont.medium(size: 0).nsFont
        crumblayer.fontSize = 12
        crumblayer.foregroundColor = BeamColor.LinkedSection.breadcrumb.cgColor

        addLayer(ButtonLayer(breadcrumbLayerName(for: index),
                             crumblayer,
                             activated: {[weak self] _ in
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

    func convertReferenceToLink() {
        guard let note = root?.note else { return }
        proxy.proxy.text.makeLinksToNoteExplicit(self, forNote: note.title)
        _ = proxy.note?.save(self)
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

    override func updateColors() {
        super.updateColors()

        performLayerChanges {
            self.containerLayer.backgroundColor = BeamColor.LinkedSection.container.cgColor
            self.linkLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        }
    }

    var actionLinkLayerheight: CGFloat { crumbsHeight + contentsPadding.bottom - 1 }
    override func updateLayout() {
        super.updateLayout()
        performLayerChanges {
            let linkLayerFrameSize = self.linkLayer.preferredFrameSize()
            if let actionLinkLayer = self.actionLinkLayer {
                actionLinkLayer.frame = CGRect(
                    origin: CGPoint(x: self.availableWidth + self.containerPadding - 36 - 4, y: self.actionLinkLayerheight),
                    size: NSSize(width: 36, height: 21)
                )
                let linkLayerXPosition = actionLinkLayer.bounds.width / 2 - linkLayerFrameSize.width / 2
                let linkLayerYPosition = actionLinkLayer.bounds.height / 2 - linkLayerFrameSize.height / 2
                self.linkLayer.frame = CGRect(x: linkLayerXPosition, y: linkLayerYPosition,
                                         width: linkLayerFrameSize.width, height: linkLayerFrameSize.height)
            }

            if self.open {
                let childrenHeight = self.idealChildrenSize.height + self.crumbsHeight - self.childrenPadding.bottom - self.childrenPadding.top - self.contentsPadding.bottom - self.contentsPadding.top
                guard let container = self.container else { return }
                container.frame = NSRect(x: 0, y: -2, width: self.availableWidth + self.containerPadding, height: childrenHeight + self.containerPadding)
            }
        }
    }

    override var mainLayerName: String {
        "BreadCrumb - \(proxy.id.uuidString) (from note \(proxy.note?.title ?? "???"))"
    }

    var isLink: Bool {
        proxyNode?.isLink ?? false
    }

    var isReference: Bool {
        !isLink
    }
}
