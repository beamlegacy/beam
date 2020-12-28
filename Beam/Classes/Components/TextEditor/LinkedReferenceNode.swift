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

    override var text: BeamText { set { proxy.text = newValue; change() } get { proxy.text } }
    public internal(set) override var children: [BeamElement] { get { proxy.children } set { proxy.children = newValue; change() } }

    override var note: BeamNote? {
        return nil
    }

    init(for element: BeamElement) {
        self.proxy = element
        super.init(proxy.text)
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

}

class LinkedReferenceNode: TextNode {
    init(editor: BeamTextEdit, parent: BreadCrumb, element: BeamElement) {
//        self.section = parent
        super.init(editor: editor, element: ProxyElement(for: element))

        editor.layer?.addSublayer(layer)
        open = false
    }

//    var section: LinksSection
}
