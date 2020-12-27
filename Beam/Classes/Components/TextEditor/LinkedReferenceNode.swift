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
    init(editor: BeamTextEdit, section: LinksSection, element: BeamElement) {
        self.section = section
        super.init(editor: editor, element: ProxyElement(for: element))

        editor.layer?.addSublayer(layer)
        open = false
        layer.backgroundColor = NSColor.green.withAlphaComponent(0.3).cgColor
    }

    var section: LinksSection

//    override func updateLayout() {
//        super.setLayout(frame)
//        print("LinkedReferenceNode.updateLayout \(frame) / \(frameInDocument)")
//    }

    public override  func draw(in context: CGContext) {
        super.draw(in: context)

//        context.saveGState()
//
//        let c = NSColor.green.cgColor
//        context.setStrokeColor(c)
//        context.stroke(contentsFrame)
//
//        context.setFillColor(c.copy(alpha: 0.4)!)
//        context.fill(contentsFrame)
//
//        context.restoreGState()
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return super.mouseDown(mouseInfo: mouseInfo)
    }
}
