//
//  ProxyTextNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit
import Combine
import BeamCore

class ProxyTextNode: TextNode, ProxyNode {

    // MARK: - Properties
    let linkTextLayer = CATextLayer()

    // MARK: - Initializer

    override init(parent: Widget, element: BeamElement) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyTextNode without a proxy provider in the parent chain") }
        super.init(parent: parent, element: proxyElement)

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
                self.children = newChildren.compactMap({ e -> ProxyTextNode? in
                    let ref = nodeFor(e, withParent: self)
                    ref.parent = self
                    return ref as? ProxyTextNode
                })

                self.invalidateRendering()
                updateChildrenVisibility(visible && open)
        }.store(in: &scope)
    }

    // MARK: - Setup UI
    override func isLinkToNote(_ text: BeamText) -> Bool {
        guard let note = editor.note as? BeamNote else { return false }
        let links = text.internalLinks
        let title = note.title
        return links.contains { range -> Bool in
            range.string.lowercased() == title.lowercased()
        }
    }

    override var isLink: Bool {
        isLinkToNote(text)
    }

    override func childrenIsLink() -> Bool {
        for c in children {
            guard let linkedRef = c as? ProxyTextNode else { return false }
            if linkedRef.isLink {
                return linkedRef.isLink
            }
            if linkedRef.childrenIsLink() {
                return true
            }
        }
        return isLink
    }

    override var mainLayerName: String {
        "ProxyTextNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
