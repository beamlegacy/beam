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

    override init(parent: Widget, element: BeamElement) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyEmbedNode without a proxy provider in the parent chain") }
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
                updateChildrenVisibility()
            }.store(in: &scope)
    }

    // MARK: - Setup UI
    override var mainLayerName: String {
        "ProxyEmbedNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
