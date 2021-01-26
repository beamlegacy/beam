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

    // MARK: - Properties
    internal var proxyChildren = [LinkedReferenceNode]()
    internal override var children: [Widget] {
        get {
            return proxyChildren
        }
        set {
            fatalError()
        }
    }

    let linkTextLayer = CATextLayer()

    // MARK: - Initializer

    override init(editor: BeamTextEdit, element: BeamElement) {
        let proxyElement = ProxyElement(for: element)
        super.init(editor: editor, element: proxyElement)

        self.proxyChildren = proxyElement.proxyChildren.compactMap({ e -> LinkedReferenceNode? in
            let ref = editor.nodeFor(e)
            ref.parent = self
            return ref as? LinkedReferenceNode
        })

        editor.layer?.addSublayer(layer)
        actionLayer?.removeFromSuperlayer()
        open = true
    }

    // MARK: - Setup UI

    func createLinkActionLayer(with note: BeamNote) {
        linkTextLayer.string = "Link"
        linkTextLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkTextLayer.fontSize = 13
        linkTextLayer.foregroundColor = NSColor.editorSearchNormal.cgColor
        linkTextLayer.contentsScale = contentsScale

        layer.addSublayer(linkTextLayer)
    }

    func updateLinknActionLayer() {
        linkTextLayer.frame = CGRect(origin: CGPoint(x: availableWidth - 12, y: 0), size: linkTextLayer.preferredFrameSize())
    }

    // MARK: - Mouse events

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return true
    }

    override func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        let position = actionLayerMousePosition(from: mouseInfo)
        self.linkTextLayer.foregroundColor = linkTextLayer.frame.contains(position) ? NSColor.linkedActionButtonHoverColor.cgColor :NSColor.linkedActionButtonColor.cgColor

        return true
    }
}
