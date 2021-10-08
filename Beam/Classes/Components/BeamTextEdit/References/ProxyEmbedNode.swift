//
//  ProxyEmbedNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/05/2021.
//

import Foundation
import AppKit
import Combine
import BeamCore

class ProxyEmbedNode: EmbedNode, ProxyNode {

    // MARK: - Initializer

    override init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyEmbedNode without a proxy provider in the parent chain") }
        super.init(parent: parent, element: proxyElement, availableWidth: availableWidth)

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
                self.children = newChildren.compactMap({ e -> ProxyTextNode? in
                    let ref = nodeFor(e, withParent: self)
                    ref.parent = self
                    return ref as? ProxyTextNode
                })

                self.invalidateRendering()
                updateChildrenVisibility()
            }.store(in: &scope)
        self.contentsPadding = NSEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)

    }

    // MARK: - Setup UI
    override var mainLayerName: String {
        "ProxyEmbedNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
