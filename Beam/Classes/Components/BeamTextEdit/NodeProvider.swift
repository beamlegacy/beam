//
//  NodeProvider.swift
//  Beam
//
//  Created by Sebastien Metrot on 04/06/2021.
//

import Foundation
import BeamCore

protocol NodeProvider: AnyObject {
    var holder: Widget? { get set }
    func proxyFor(_ element: BeamElement) -> ProxyElement?
    func nodeFor(_ element: BeamElement) -> ElementNode?
    func proxyNodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode
    func nodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode
    func clearMapping()
    func purgeDeadNodes()
    func removeNode(_ node: ElementNode)
}

class NodeProviderImpl: NodeProvider {
    weak var holder: Widget? {
        didSet {
            assert(holder?.editor != nil)
        }
    }
    var proxy: Bool

    init(proxy: Bool) {
        self.proxy = proxy

        if proxy, let breadCrumd = holder as? BreadCrumb {
            proxies[breadCrumd.proxy.proxy] = WeakReference(breadCrumd.proxy)
        } else if let elementNode = holder as? ElementNode {
            mapping[elementNode.element] = WeakReference(elementNode)
        }
    }

    private var proxies: [BeamElement: WeakReference<ProxyElement>] = [:]
    func proxyFor(_ element: BeamElement) -> ProxyElement? {
        assert(element as? ProxyElement == nil) // Don't create a proxy to a proxy

        if let proxy = proxies[element]?.ref {
            return proxy
        }
        let proxy = ProxyElement(for: element)
        proxies[element] = WeakReference(proxy)
        return proxy
    }

    func nodeFor(_ element: BeamElement) -> ElementNode? {
        if let h = (holder as? ElementNode), h.displayedElement.id == element.id {
            return h
        }
        return mapping[element]?.ref
    }

    func proxyNodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode {
        if let h = (holder as? ProxyNode), h.displayedElement.id == element.id {
            h.parent = withParent
            return h
        }

        if let node = mapping[element]?.ref as? ProxyNode {
            if node.parent != withParent {
                node.parent = withParent
            }
            return node
        }

        // BreadCrumbs can't create TextNodes, only ProxyTextNodes
        let width = withParent.childAvailableWidth
        let node: ElementNode = {
            switch element.kind {
            case .image:
                return ProxyImageNode(parent: withParent, element: element, availableWidth: width)
            case .embed:
                return ProxyEmbedNode(parent: withParent, element: element, availableWidth: width)
            case .blockReference:
                return BlockReferenceNode(parent: withParent, element: element, availableWidth: width)
            case .divider:
                return DividerNode(parent: withParent, element: element, availableWidth: width)
            case .code:
                return ProxyCodeNode(parent: withParent, element: element, availableWidth: width)
            default:
                return ProxyTextNode(parent: withParent, element: element, availableWidth: width)
            }
        }()

        accessingMapping = true
        mapping[element] = WeakReference(node)
        accessingMapping = false
        purgeDeadNodes()

        if let holder = holder {
            node.contentsScale = holder.contentsScale
        }
        return node
    }

    func nodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode {
        guard !proxy,
              element as? ProxyElement == nil else {
            return proxyNodeFor(element, withParent: withParent)
        }

        if let h = (holder as? ElementNode), h.displayedElement.id == element.id {
            h.parent = withParent
            return h
        }

        if let node = mapping[element]?.ref {
            if node.parent != withParent {
                node.parent = withParent
            }
            return node
        }

        // BreadCrumbs can't create TextNodes, only ProxyTextNodes
        let width = withParent.childAvailableWidth
        let node: ElementNode = {
            guard let note = element as? BeamNote else {
                guard element.note == nil || element.note == holder?.root?.note else {
                    return ProxyTextNode(parent: withParent, element: element, availableWidth: width)
                }

                switch element.kind {
                case .image:
                    return ImageNode(parent: withParent, element: element, availableWidth: width)
                case .embed:
                    return EmbedNode(parent: withParent, element: element, availableWidth: width)
                case .blockReference:
                    return BlockReferenceNode(parent: withParent, element: element, availableWidth: width)
                case .divider:
                    return DividerNode(parent: withParent, element: element, availableWidth: width)
                case .tabGroup:
                    return TabGroupNode(parent: withParent, element: element, availableWidth: width)
                case .code:
                    return CodeNode(parent: withParent, element: element, availableWidth: width)
                default:
                    return TextNode(parent: withParent, element: element, availableWidth: width)
                }
            }
            guard let editor = holder?.editor else { fatalError() }
            return TextRoot(editor: editor, element: note, availableWidth: BeamTextEdit.textNodeWidth(for: editor.frame.size))
        }()

        accessingMapping = true
        mapping[element] = WeakReference(node)
        accessingMapping = false
        purgeDeadNodes()

        node.contentsScale = holder!.contentsScale

        guard let editor = holder?.editor else { fatalError() }
        editor.addToMainLayer(node.layer)

        return node
    }

    func clearMapping() {
        mapping.removeAll()
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

    func removeNode(_ node: ElementNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }
}
