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
    var imageSize = CGSize.zero
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

    func setupImage() {
        var uid = ""
        switch element.kind {
        case .image(let id):
            uid = id
        default:
            Logger.shared.logError("ImageNode can only handle image elements, not \(element.kind)", category: .noteEditor)
            return
        }
        guard let imageRecord = try? AppDelegate.main.data.fileDB.fetch(uid: uid)
        else {
            Logger.shared.logError("ImageNode unable to fetch image '\(uid)' from FileDB", category: .noteEditor)
            return
        }

        if let animatedLayer = Layer.animatedImage(named: "image", imageData: imageRecord.data) {
            animatedLayer.layer.position = CGPoint(x: 0, y: 0)
            addLayer(animatedLayer, origin: CGPoint(x: 0, y: 0))
            imageSize = animatedLayer.bounds.size
            return
        }

        guard let image = NSImage(data: imageRecord.data)
        else {
            Logger.shared.logError("ImageNode unable to decode image '\(uid)' from FileDB", category: .noteEditor)
            return
        }

        imageSize = image.size
        guard imageSize.width > 0,
              imageSize.width.isFinite,
              imageSize.height > 0,
              imageSize.height.isFinite else {
            Logger.shared.logError("Loaded Image '\(uid)' has invalid size \(imageSize)", category: .noteEditor)
            return
        }
        let width = availableWidth - childInset
        let height = (width / imageSize.width) * imageSize.height

        let imageLayer = Layer.image(named: "image", image: image, size: CGSize(width: width, height: height))
        addLayer(imageLayer, origin: CGPoint(x: 0, y: 0))

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)

        contentsPadding = NSEdgeInsets(top: 4, left: contentsPadding.left + 4, bottom: 14, right: 4)
    }

    override func updateRendering() -> CGFloat {
        updateFocus()
        return visibleSize.height
    }

    override func updateLayout() {
        super.updateLayout()
        if let imageLayer = layers["image"] {
            imageLayer.layer.position = CGPoint(x: contentsLead, y: contentsTop)
            imageLayer.layer.bounds = CGRect(origin: .zero, size: visibleSize)
        }
    }

    public override func updateElementCursor() {
        let imageLayer = layers["image"]?.layer
        let bounds = imageLayer?.bounds ?? .zero
        let cursorRect = NSRect(x: caretIndex == 0 ? -4 : (bounds.width + 2), y: -focusMargin, width: 2, height: bounds.height + focusMargin * 2)
        layoutCursor(cursorRect)
    }

    var focusMargin = CGFloat(3)
    override func updateFocus() {
        guard let imageLayer = layers["image"] else { return }

        imageLayer.layer.sublayers?.forEach { l in
            l.removeFromSuperlayer()
        }
        guard isFocused else {
            imageLayer.layer.mask = nil
            return
        }
        let bounds = imageLayer.bounds.insetBy(dx: -focusMargin, dy: -focusMargin)
        let position = CGPoint(x: 0, y: 0)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2)

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.position = position

        let borderPath = NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2)
        let borderLayer = CAShapeLayer()
        borderLayer.path = borderPath.cgPath
        borderLayer.lineWidth = 5
        borderLayer.strokeColor = selectionColor.cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.bounds = bounds
        borderLayer.position = CGPoint(x: imageLayer.layer.bounds.width / 2, y: imageLayer.layer.bounds.height / 2)
        borderLayer.mask = mask
        imageLayer.layer.addSublayer(borderLayer)
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }
}

// MARK: - ImageNode + Layer
extension ImageNode {
    override var bulletLayerPositionY: CGFloat { 9 }
}
