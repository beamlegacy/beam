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

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyTextNode without a proxy provider in the parent chain") }
        super.init(parent: parent, element: proxyElement, availableWidth: availableWidth)

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
                guard self.editor != nil, parent != nil else { return }
                self.children = newChildren.compactMap({ e -> ProxyTextNode? in
                    let ref = nodeFor(e, withParent: self)
                    ref.parent = self
                    return ref as? ProxyTextNode
                })

                self.invalidateRendering()
                updateChildrenVisibility()
        }.store(in: &scope)
    }

    override func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        switch elementKind {
        case .check:
            return NSEdgeInsets(top: 0, left: 20, bottom: 0, right: isLink ? 10 : 50)
        default:
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: isLink ? 10 : 50)
        }
    }

    // MARK: - Setup UI

    override func updateSelectionLayer() {
        super.updateSelectionLayer()
        selectionLayer.bounds.size.width -= 20
    }

    override func isLinkToNote(_ text: BeamText) -> Bool {
        guard let note = editor?.note as? BeamNote else { return false }
        return text.internalLinks.contains(note.id)
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
