//
//  ProxyImageNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit
import Combine
import BeamCore

class ProxyImageNode: ImageNode, ProxyNode {

    // MARK: - Initializer

    override init(parent: Widget, element: BeamElement) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyImageNode without a proxy provider in the parent chain") }
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
    override var mainLayerName: String {
        "ProxyImageNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
