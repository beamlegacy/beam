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
    var didMakeInternalLink: ((_ text: String) -> Void)?

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

    func createLinkActionLayer() {
        linkTextLayer.string = "Link"
        linkTextLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkTextLayer.fontSize = 13
        linkTextLayer.foregroundColor = NSColor.linkedActionButtonColor.cgColor
        linkTextLayer.contentsScale = contentsScale

        addLayer(Layer(
                name: "LinkLayer",
                layer: linkTextLayer,
                mouseXPosition: indent,
                down: { [weak self] _ in
                    guard let self = self, let didMakeInternalLink = self.didMakeInternalLink else { return false }
                    self.text.makeInternalLink(self.cursorsStartPosition..<self.text.text.count)
                    didMakeInternalLink(self.text.text)
                    return true
                },
                hover: { (isHover) in
                    self.linkTextLayer.foregroundColor = isHover ? NSColor.linkedActionButtonHoverColor.cgColor : NSColor.linkedActionButtonColor.cgColor
                }
            )
        )
    }

    override func updateSubLayersLayout() {
        layers["LinkLayer"]?.frame = CGRect(origin: CGPoint(x: frame.width - 12, y: 0), size: linkTextLayer.preferredFrameSize())
    }
}
