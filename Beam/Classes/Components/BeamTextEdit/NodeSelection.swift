//
//  NodeSelection.swift
//  Beam
//
//  Created by Sebastien Metrot on 12/01/2021.
//

import Foundation
import BeamCore

class NodeSelection {
    var start: TextNode
    var end: TextNode

    /// All the selected nodes
    public private(set) var nodes: Set<TextNode>

    /// All the selected nodes, sorted from top to bottom
    public var sortedNodes: [TextNode] {
        nodes.sorted { (node1, node2) -> Bool in
            node1.isAbove(node: node2)
        }
    }

    /// Return the nodes that are selected and for which the parent isn't in the list of selected nodes
    public var roots: [TextNode] {
        nodes.compactMap({ (node) -> TextNode? in
            for p in node.allParents {
                guard let p = p as? TextNode else { continue }
                if nodes.contains(p) {
                    return nil
                }
            }
            return node
        })
    }

    /// All the selected roots, sorted from top to bottom
    public var sortedRoots: [TextNode] {
         roots.sorted { (node1, node2) -> Bool in
            node1.isAbove(node: node2)
        }
    }

    init(start: TextNode, end: TextNode, elements: Set<TextNode> = Set<TextNode>()) {
        self.start = start
        self.end = end
        self.nodes = elements

        selectRange(start: start, end: end)
    }

    private func _selectRange(start: TextNode, end: TextNode) {
        var node = start
        while node != end {
            append(node)
            if let nextVisible = node.nextVisibleTextNode() {
                node = nextVisible
            } else {
                Logger.shared.logError("unable to select node range", category: .document)
                return
            }
        }
        append(end)
    }

    func selectRange(start: TextNode, end: TextNode) {
        if start.isAbove(node: end) {
            _selectRange(start: start, end: end)
        } else {
            _selectRange(start: end, end: start)
        }
    }

    func extendUp() {
        guard let next = end.previousVisibleTextNode(),
              type(of: end) == type(of: next) else { return }

        if next.isAbove(node: start) {
            end = next
            append(end)
        } else {
            if start != end {
                remove(end)
            }
            end = next
        }
    }

    func extendDown() {
        guard let next = end.nextVisibleTextNode(),
              type(of: end) == type(of: next) else { return }

        if next.isAbove(node: start) || next == start {
            if start != end {
                remove(end)
            }
            end = next
        } else {
            end = next
            append(end)
        }
    }

    func append(_ node: TextNode) {
        node.selected = true
        nodes.insert(node)
        if nodes.count > 1 {
            nodes.forEach { (node) in
                node.selectedAlone = false
            }
        }

        if !node.open {
            appendChildren(of: node)
        }
    }

    func remove(_ node: TextNode) {
        node.selected = false
        node.selectedAlone = true
        nodes.remove(node)
        if nodes.count < 2 {
            nodes.forEach { (node) in
                node.selectedAlone = true
            }
        }

        if !node.open {
            removeChildren(of: node)
        }
    }

    func appendChildren(of node: TextNode) {
        for child in node.children {
            guard let child = child as? TextNode else { continue }
            child.selectedAlone = false
            child.selected = true
            nodes.insert(child)

            appendChildren(of: child)
        }
    }

    func removeChildren(of node: TextNode) {
        for child in node.children {
            guard let child = child as? TextNode else { continue }
            child.selected = false
            nodes.insert(child)

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
