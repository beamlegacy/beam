//
//  ImageNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/05/2021.
//

import Foundation
import BeamCore
import AppKit

class ImageNode: ElementNode {

    private let focusMargin = CGFloat(3)
    private let cornerRadius = CGFloat(3)
    private var imageSize = CGSize.zero

    var visibleSize: CGSize {
        let computedWidth = imageSize.width > contentsWidth ? contentsWidth : imageSize.width
        let width = computedWidth.isNaN ? 0 : computedWidth
        let computedHeight = (width / imageSize.width) * imageSize.height
        let height = computedHeight.isNaN ? 0 : computedHeight
        return NSSize(width: width, height: height)
    }

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)
        setupImage()
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element)
        setupImage()
    }

    private func setupImage() {
        var uid = UUID.null
        switch element.kind {
        case .image(let id):
            uid = id
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
            imageSize = animatedImageLayer.bounds.size
        } else {
            guard let image = NSImage(data: imageRecord.data) else {
                Logger.shared.logError("ImageNode unable to decode image '\(uid)' from FileDB", category: .noteEditor)
                return
            }

            imageSize = image.size
            guard imageSize.width > 0, imageSize.width.isFinite,
                  imageSize.height > 0, imageSize.height.isFinite else {
                Logger.shared.logError("Loaded Image '\(uid)' has invalid size \(imageSize)", category: .noteEditor)
                return
            }
            let width = availableWidth - childInset
            let height = (width / imageSize.width) * imageSize.height
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
        if mouseInfo.position.x < imageSize.width / 2 {
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
