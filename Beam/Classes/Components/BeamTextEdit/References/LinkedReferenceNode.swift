//
//  LinkedReferenceNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit
import Combine
import BeamCore

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
            .sink { [unowned self] newChildren in
            updating = true; defer { updating = false }
            self.updateProxyChildren(newChildren)
        }.store(in: &scope)

        proxy.$text
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            text = newValue
        }.store(in: &scope)

        proxy.$kind
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            kind = newValue
        }.store(in: &scope)

        proxy.$childrenFormat
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            childrenFormat = newValue
        }.store(in: &scope)

        proxy.$updateDate
            .sink { [unowned self] newValue in
            updating = true; defer { updating = false }
            updateDate = newValue
        }.store(in: &scope)
    }

    func updateProxyChildren(_ newChildren: [BeamElement]) {
        self.children = newChildren
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

}

class LinkedReferenceNode: TextNode {

    // MARK: - Properties
    let linkTextLayer = CATextLayer()

    // MARK: - Initializer

    override init(parent: Widget, element: BeamElement) {
        guard let proxyElement = parent.proxyFor(element) else { fatalError("Can't create a LinkedReferenceNode without a proxy provider in the parent chain") }
        super.init(parent: parent, element: proxyElement)

        actionLayer?.removeFromSuperlayer()

        createLinkActionLayer()

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] newChildren in
                self.children = newChildren.compactMap({ e -> LinkedReferenceNode? in
                    let ref = nodeFor(e, withParent: self)
                    ref.parent = self
                    return ref as? LinkedReferenceNode
                })

                self.invalidateRendering()
                updateChildrenVisibility(visible && open)
        }.store(in: &scope)

        element.$text.sink { [unowned self] text in
            self.layers["LinkLayer"]?.layer.isHidden = self.isLinkToNote(text) || !shouldDisplayLinkButton
        }.store(in: &scope)
    }

    // MARK: - Setup UI

    func createLinkActionLayer() {
        linkTextLayer.string = "Link"
        linkTextLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        linkTextLayer.fontSize = 13
        linkTextLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkTextLayer.contentsScale = contentsScale

        addLayer(ButtonLayer(
            "LinkLayer",
            linkTextLayer,
            activated: { [weak self] in
                self?.makeInternalLink()
                return
            },
            hovered: { (isHover) in
                self.linkTextLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
            }
        ))
    }

    override func updateSubLayersLayout() {
        CATransaction.disableAnimations {
            layers["LinkLayer"]?.frame = CGRect(origin: CGPoint(x: frame.width - 12, y: 0), size: linkTextLayer.preferredFrameSize())
        }
    }

    func isLinkToNote(_ text: BeamText) -> Bool {
        guard let note = editor.note as? BeamNote else { return false }
        let links = text.internalLinks
        let title = note.title
        return links.contains { range -> Bool in
            range.string == title
        }
    }
    var isLink: Bool {
        isLinkToNote(text)
    }

    var isReference: Bool {
        !isLink
    }

    var shouldDisplayLinkButton: Bool {
        guard let proxy = element as? ProxyElement else { return false }
        return proxy.proxy.depth < 2
    }

    func makeInternalLink() {
        guard let note = editor.note as? BeamNote else { return }
        guard !isLink else { return }
        let title = note.title

        text.makeLinkToNoteExplicit(forNote: title)

        let reference = BeamNoteReference(noteTitle: element.note!.title, elementID: element.id)
        note.addReference(reference)

        self.editor.showOrHidePersistentFormatter(isPresent: false)
    }

    override var mainLayerName: String {
        "LinkReferenceNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }
}
