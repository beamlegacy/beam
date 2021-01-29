//
//  LinkedReferenceNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit
import Combine

class ProxyElement: BeamElement {
    var proxy: BeamElement

    override var text: BeamText {
        didSet {
            proxy.text = text
        }
    }
    override var note: BeamNote? {
        return proxy.note
    }

    var scope = Set<AnyCancellable>()

    init(for element: BeamElement) {
        self.proxy = element
        super.init(proxy.text)
        proxy.$children.sink { [unowned self] newChildren in
            self.updateProxyChildren(newChildren)
        }.store(in: &scope)
    }

    func updateProxyChildren(_ newChildren: [BeamElement]) {
        self.children = newChildren.map({ e -> ProxyElement in
            let p = ProxyElement(for: e)
            p.parent = proxy
            return p
        })
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

}

class LinkedReferenceNode: TextNode {

    // MARK: - Properties

    internal var storedChildren: [Widget] = []
    internal override var children: [Widget] {
        get {
            storedChildren
        }
        set {
            storedChildren = newValue
        }
    }

    let linkTextLayer = CATextLayer()
    var didMakeInternalLink: ((_ text: String) -> Void)?

    // MARK: - Initializer

    override init(editor: BeamTextEdit, element: BeamElement) {
        let proxyElement = ProxyElement(for: element)
        super.init(editor: editor, element: proxyElement)

        editor.layer?.addSublayer(layer)
        actionLayer?.removeFromSuperlayer()
        open = true

        element.$children
            .sink { [unowned self] newChildren in
                self.children = newChildren.compactMap({ e -> LinkedReferenceNode? in
                    let ref = editor.nodeFor(e)
                    ref.parent = self
                    return ref as? LinkedReferenceNode
                })

                self.invalidateRendering()
                self.invalidateLayout()
        }.store(in: &scope)

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
                down: { [weak self] _ in
                    guard let self = self, let didMakeInternalLink = self.didMakeInternalLink else { return false }
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
        CATransaction.disableAnimations {
            layers["LinkLayer"]?.frame = CGRect(origin: CGPoint(x: frame.width - 12, y: 0), size: linkTextLayer.preferredFrameSize())
        }
    }
}
