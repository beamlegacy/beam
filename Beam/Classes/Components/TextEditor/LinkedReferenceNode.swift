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
            guard !updating else { return }
            proxy.text = text
        }
    }

    override var kind: ElementKind {
        didSet {
            guard !updating else { return }
            proxy.kind = kind
        }
    }

    override var childrenFormat: ElementChildrenFormat {
        didSet {
            guard !updating else { return }
            proxy.childrenFormat = childrenFormat
        }
    }

    override var updateDate: Date {
        didSet {
            guard !updating else { return }
            proxy.updateDate = updateDate
        }
    }

    override var note: BeamNote? {
        return proxy.note
    }

    var updating = false
    var scope = Set<AnyCancellable>()

    init(for element: BeamElement) {
        self.proxy = element
        super.init(proxy.text)
        proxy.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
            updating = true; defer { updating = false }
            self.updateProxyChildren(newChildren)
        }.store(in: &scope)

        proxy.$text
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            text = newValue
        }.store(in: &scope)

        proxy.$kind
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            kind = newValue
        }.store(in: &scope)

        proxy.$childrenFormat
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            childrenFormat = newValue
        }.store(in: &scope)

        proxy.$updateDate
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            updateDate = newValue
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
    let linkTextLayer = CATextLayer()
    var didMakeInternalLink: ((_ text: String) -> Void)?

    // MARK: - Initializer

    override init(editor: BeamTextEdit, element: BeamElement) {
        let proxyElement = ProxyElement(for: element)
        super.init(editor: editor, element: proxyElement)
        self.children = proxyElement.children.compactMap({ e -> LinkedReferenceNode? in
            let ref = nodeFor(e)
            ref.parent = self
            return ref as? LinkedReferenceNode
        })

        editor.layer?.addSublayer(layer)
        actionLayer?.removeFromSuperlayer()

        open = false

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
                self.children = newChildren.compactMap({ e -> LinkedReferenceNode? in
                    let ref = nodeFor(e)
                    ref.parent = self
                    return ref as? LinkedReferenceNode
                })

                self.invalidateRendering()
                updateChildrenVisibility(visible && open)
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
