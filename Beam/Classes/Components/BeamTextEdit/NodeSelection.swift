//
//  NodeSelection.swift
//  Beam
//
//  Created by Sebastien Metrot on 12/01/2021.
//

import Foundation
import BeamCore

class NodeSelection {
    var start: ElementNode
    var end: ElementNode
    var isSelectingProxy: Bool = false

    /// All the selected nodes
    public private(set) var nodes: Set<ElementNode>

    /// All the selected nodes, sorted from top to bottom
    public var sortedNodes: [ElementNode] {
        nodes.sorted { (node1, node2) -> Bool in
            node1.isAbove(node: node2)
        }
    }

    private var minOffset: CGFloat {
        nodes.min { $0.offsetInRoot.x < $1.offsetInRoot.x }?.offsetInRoot.x ?? 0
    }

    /// Return the nodes that are selected and for which the parent isn't in the list of selected nodes
    public var roots: [ElementNode] {
        nodes.compactMap({ (node) -> ElementNode? in
            for p in node.allParents {
                guard let p = p as? ElementNode else { continue }
                if nodes.contains(p) {
                    return nil
                }
            }
            return node
        })
    }

    /// All the selected roots, sorted from top to bottom
    public var sortedRoots: [ElementNode] {
         roots.sorted { (node1, node2) -> Bool in
            node1.isAbove(node: node2)
        }
    }

    /// Return true if at least one TextNode is inside the selection
    public var hasTextNode: Bool {
        nodes.contains(where: { $0 is TextNode })
    }

    init(start: ElementNode, end: ElementNode, elements: Set<ElementNode> = Set<ElementNode>()) {
        self.start = start
        self.end = end
        self.nodes = elements
        self.isSelectingProxy = ((start as? ProxyNode) != nil)
        selectRange(start: start, end: end)
    }

    private func _selectRange(start: ElementNode, end: ElementNode) {
        var node = start
        while node != end {
            append(node)
            if let nextVisible = node.nextVisibleNode(ElementNode.self) {
                node = nextVisible
            } else {
                Logger.shared.logError("unable to select node range", category: .document)
                return
            }
        }
        append(end)
    }

    func selectRange(start: ElementNode, end: ElementNode) {
        if start.isAbove(node: end) {
            _selectRange(start: start, end: end)
        } else {
            _selectRange(start: end, end: start)
        }
    }

    func extendUp() {
        guard let previousVisibleNode = end.previousVisibleNode(ElementNode.self) else { return }
        if isSelectingProxy {
            guard ((previousVisibleNode as? ProxyNode) != nil), previousVisibleNode.element.note == start.element.note, isSelectingProxy else { return }
        }

        if previousVisibleNode.isAbove(node: start) {
            end = previousVisibleNode
            append(end)
        } else {
            if start != end {
                remove(end)
            }
            end = previousVisibleNode
        }
    }

    func extendDown() {
        guard let nextVisibleNode = end.nextVisibleNode(ElementNode.self) else { return }
        if isSelectingProxy {
            guard ((nextVisibleNode as? ProxyNode) != nil), nextVisibleNode.element.note == start.element.note else { return }
        } else {
            guard (nextVisibleNode as? ProxyNode) == nil else { return }
        }

        if nextVisibleNode.isAbove(node: start) || nextVisibleNode == start {
            if start != end {
                remove(end)
            }
            end = nextVisibleNode
        } else {
            end = nextVisibleNode
            append(end)
        }
    }

    func append(_ node: ElementNode) {
        if isSelectingProxy {
            guard ((node as? ProxyNode) != nil), node.element.note == start.element.note else { return }
        } else {
            guard (node as? ProxyNode) == nil else { return }
        }

        node.selected = true
        nodes.insert(node)
        if nodes.count > 1 {
            nodes.forEach { (node) in
                node.selectionLayerPosX = minOffset - node.offsetInRoot.x
                node.selectedAlone = false
            }
        }

        if !node.open {
            appendChildren(of: node)
        }
    }

    func remove(_ node: ElementNode) {
        if isSelectingProxy {
            guard ((node as? ProxyNode) != nil), node.element.note == start.element.note else { return }
        }
        node.selected = false
        node.selectedAlone = true
        nodes.remove(node)
        if nodes.count < 2 {
            nodes.forEach { (node) in
                node.selectedAlone = true
            }
        } else {
            nodes.forEach { (node) in
                node.selectionLayerPosX = minOffset - node.offsetInRoot.x
            }
        }

        if !node.open {
            removeChildren(of: node)
        }
    }

    func appendChildren(of node: ElementNode) {
        for child in node.children {
            guard let child = child as? ElementNode else { continue }
            child.selectionLayerPosX = minOffset - child.offsetInRoot.x
            child.selectedAlone = false
            child.selected = true
            nodes.insert(child)

            appendChildren(of: child)
        }
    }

    func removeChildren(of node: ElementNode) {
        for child in node.children {
            guard let child = child as? ElementNode,
                    let childIdx = nodes.firstIndex(of: child) else { continue }
            child.selected = false
            nodes.remove(at: childIdx)

            removeChildren(of: child)
        }
    }

    func cancelSelection() {
        for node in nodes {
            node.selected = false
            node.selectedAlone = true
        }
        nodes.removeAll()
    }

    deinit {
        cancelSelection()
    }
}
