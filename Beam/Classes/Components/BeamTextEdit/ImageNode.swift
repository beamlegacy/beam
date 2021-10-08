//
//  ImageNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/05/2021.
//

import Foundation
import BeamCore
import AppKit

class ImageNode: ResizableNode {

    private let focusMargin = CGFloat(3)
    private let cornerRadius = CGFloat(3)

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        super.init(parent: parent, element: element, availableWidth: availableWidth)
        setupImage(width: availableWidth ?? fallBackWidth)
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat?) {
        super.init(editor: editor, element: element, availableWidth: availableWidth)
        setupImage(width: availableWidth ?? fallBackWidth)
    }

    private func setupImage(width: CGFloat) {
        var uid = UUID.null
        switch element.kind {
        case .image(let id, let ratio):
            uid = id
            desiredWidthRatio = ratio
        default:
            Logger.shared.logError("ImageNode can only handle image elements, not \(element.kind)", category: .noteEditor)
            return
        }
        guard let imageRecord = try? BeamFileDBManager.shared.fetch(uid: uid)
        else {
            Logger.shared.logError("ImageNode unable to fetch image '\(uid)' from FileDB", category: .noteEditor)
            return
        }

        var imageLayer: Layer
        if let animatedImageLayer = Layer.animatedImage(named: "image", imageData: imageRecord.data) {
            animatedImageLayer.layer.position = .zero
            imageLayer = animatedImageLayer
            resizableElementContentSize = animatedImageLayer.bounds.size
        } else {
            guard let image = NSImage(data: imageRecord.data) else {
                Logger.shared.logError("ImageNode unable to decode image '\(uid)' from FileDB", category: .noteEditor)
                return
            }

            resizableElementContentSize = image.size
            guard resizableElementContentSize.width > 0, resizableElementContentSize.width.isFinite,
                  resizableElementContentSize.height > 0, resizableElementContentSize.height.isFinite else {
                Logger.shared.logError("Loaded Image '\(uid)' has invalid size \(resizableElementContentSize)", category: .noteEditor)
                return
            }
//            let width = width
            let height = (width / resizableElementContentSize.width) * resizableElementContentSize.height
            imageLayer = Layer.image(named: "image", image: image, size: CGSize(width: width, height: height))
        }

        imageLayer.layer.cornerRadius = cornerRadius
        imageLayer.layer.masksToBounds = true
        imageLayer.layer.zPosition = 1
        addLayer(imageLayer, origin: .zero)

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)

        contentsPadding = NSEdgeInsets(top: 4, left: contentsPadding.left + 4, bottom: 14, right: 4)

        setupFocusLayer()
        setupResizeHandleLayer()
    }

    private func setupFocusLayer() {
        let bounds = CGRect.zero
        let borderLayer = CAShapeLayer()
        borderLayer.lineWidth = 5
        borderLayer.strokeColor = selectionColor.cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.bounds = bounds
        borderLayer.position = .zero
        borderLayer.zPosition = 0
        let focusLayer = Layer(name: "focus", layer: borderLayer)
        addLayer(focusLayer, origin: .zero)
    }

    override func updateRendering() -> CGFloat {
        updateFocus()
        return visibleSize.height
    }

    override func updateLayout() {
        super.updateLayout()
        if let imageLayer = layers["image"] {
            let position = CGPoint(x: contentsLead, y: contentsTop)
            let bounds = CGRect(origin: .zero, size: visibleSize)
            guard bounds != imageLayer.layer.bounds || position != imageLayer.layer.position else { return }
            imageLayer.layer.position = position
            imageLayer.layer.bounds = bounds

            if let focusLayer = layers["focus"], let borderLayer = focusLayer.layer as? CAShapeLayer {
                let focusBounds = bounds.insetBy(dx: -focusMargin / 2, dy: -focusMargin / 2)
                let borderPath = NSBezierPath(roundedRect: focusBounds, xRadius: cornerRadius, yRadius: cornerRadius)
                borderLayer.path = borderPath.cgPath
                borderLayer.position = CGPoint(x: position.x + bounds.size.width / 2, y: position.y + bounds.size.height / 2)
                borderLayer.bounds = focusBounds
            }
        }
    }

    public override func updateElementCursor() {
        let containerLayer = layers["image"]?.layer
        let bounds = containerLayer?.bounds ?? .zero
        let cursorRect = NSRect(x: caretIndex == 0 ? -4 : (bounds.width + 2), y: -focusMargin, width: 2, height: bounds.height + focusMargin * 2)
        layoutCursor(cursorRect)
    }

    override func updateFocus() {
        guard let focusLayer = layers["focus"] else { return }
        focusLayer.layer.opacity = isFocused ? 1 : 0
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        if mouseInfo.position.x < resizableElementContentSize.width / 2 {
            focus(position: 0)
        } else {
            focus(position: 1)
        }
        dragMode = .select(0)
        return true
    }
}

// MARK: - ImageNode + Layer
extension ImageNode {
    override var bulletLayerPositionY: CGFloat { 9 }
}
