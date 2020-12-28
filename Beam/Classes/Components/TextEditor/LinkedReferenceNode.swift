//
//  LinkedReferenceNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit

class ProxyElement: BeamElement {
    var proxy: BeamElement
    var proxyChildren: [BeamElement]

    override var text: BeamText { set { proxy.text = newValue; change() } get { proxy.text } }
    public internal(set) override var children: [BeamElement] { get { proxyChildren } set { fatalError() } }

    override var note: BeamNote? {
        return nil
    }

    init(for element: BeamElement) {
        self.proxy = element
        self.proxyChildren = element.children.map({ e -> ProxyElement in
            let p = ProxyElement(for: e)
            p.parent = element
            return p
        })
        super.init(proxy.text)
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

}

class LinkedReferenceNode: TextNode {
    init(editor: BeamTextEdit, parent: Widget, element: BeamElement) {
//        self.section = parent
        let proxyElement = ProxyElement(for: element)
        super.init(editor: editor, element: proxyElement)
        self.proxyChildren = proxyElement.proxyChildren.map({ e -> LinkedReferenceNode in
            LinkedReferenceNode(editor: editor, parent: self, element: e)
        })

        self.parent = parent
        editor.layer?.addSublayer(layer)
        open = true
    }

    internal var proxyChildren = [LinkedReferenceNode]()
    internal override var children: [Widget] {
        get {
            return proxyChildren
        }
        set {
            fatalError()
        }
    }
}
