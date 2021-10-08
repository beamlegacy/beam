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

    override init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a ProxyImageNode without a proxy provider in the parent chain") }
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
        "ProxyImageNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
