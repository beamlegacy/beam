//
//  ProxyTextNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import AppKit
import Combine
import BeamCore

class ProxyTextNode: TextNode, ProxyNode {

    // MARK: - Properties
    let linkTextLayer = CATextLayer()

    var referencesRanges: [Range<Int>]? {
        var result: [Range<Int>] = []
        for range in text.ranges {
            if let noteTitle = editor?.note.note?.title {
                let cleanRanges = range.string.lowercased().ranges(of: noteTitle.lowercased())
                for cleanRange in cleanRanges {
                    result.append(range.string.range(from: cleanRange))
                }
            }
        }
        return result.isEmpty ?  nil : result
    }

    // MARK: - Initializer

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        // We must create a fake element if we're building on a dead branch of the document tree, it will just disapear soon without breaking.
        let proxyElement = parent.proxyFor(element) ?? BeamElement()
        super.init(parent: parent, element: proxyElement, availableWidth: availableWidth)

        element.$children
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newChildren in
                guard let self = self,
                      self.parent != nil,
                      self.root != nil,
                      self.editor != nil,
                      self.isInNodeProviderTree
                else { return }
                self.children = newChildren.compactMap({ e -> Widget? in
                    let ref = self.nodeFor(e, withParent: self)
                    ref.parent = self
                    return ref
                })

                self.invalidateRendering()
                self.updateChildrenVisibility()
        }.store(in: &scope)
    }

    // MARK: TextConfig and Paddings
    override func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        switch elementKind {
        case .check:
            return NSEdgeInsets(top: 0, left: 20, bottom: 0, right: isLink ? 10 : 50)
        default:
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: isLink ? 10 : 50)
        }
    }

    // MARK: - Setup UI

    override func updateSelectionLayer() {
        super.updateSelectionLayer()
        selectionLayer.bounds.size.width -= 20
    }

    override func isLinkToNote(_ text: BeamText) -> Bool {
        guard let note = editor?.note as? BeamNote else { return false }
        return text.internalLinks.contains(note.id)
    }

    override var isLink: Bool {
        isLinkToNote(text)
    }

    override func childrenIsLink() -> Bool {
        for c in children {
            guard let linkedRef = c as? ProxyTextNode else { return false }
            if linkedRef.isLink {
                return linkedRef.isLink
            }
            if linkedRef.childrenIsLink() {
                return true
            }
        }
        return isLink
    }

    override var mainLayerName: String {
        "ProxyTextNode - \(element.id.uuidString) (from note \(element.note?.title ?? "???"))"
    }

    override func onUnfocus() {
        if let linkSection = firstParentWithType(LinksSection.self) {
            linkSection.updateLinkedReferences(links: linkSection.links)
        }
        super.onUnfocus()
    }
}
