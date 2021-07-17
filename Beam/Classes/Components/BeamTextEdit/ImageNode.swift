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

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)

        setupImage()

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element)

        setupImage()

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)
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
            animatedLayer.layer.position = CGPoint(x: indent, y: 0)
            addLayer(animatedLayer, origin: CGPoint(x: indent, y: 0))
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
        imageLayer.layer.position = CGPoint(x: indent, y: 0)
        addLayer(imageLayer, origin: CGPoint(x: indent, y: 0))
    }

    override func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            let available = availableWidth - indent
            let computedWidth = imageSize.width > available ? available : imageSize.width
            let width = computedWidth.isNaN ? 0 : computedWidth
            let computedHeight = (width / imageSize.width) * imageSize.height
            let height = computedHeight.isNaN ? 0 : computedHeight

            contentsFrame = NSRect(x: indent, y: 0, width: width, height: height)

            if let imageLayer = layers["image"] {
                imageLayer.layer.position = CGPoint(x: indent + childInset, y: 0)
                imageLayer.layer.bounds = CGRect(origin: imageLayer.frame.origin, size: CGSize(width: width, height: height))

                updateFocus()
            }

            invalidatedRendering = false
        }

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        if open && selfVisible {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    public override func updateElementCursor() {
        let on = editor.hasFocus && isFocused && editor.blinkPhase && (root?.state.nodeSelection?.nodes.isEmpty ?? true)
        let cursorRect = NSRect(x: caretIndex == 0 ? (indent - 5) : (contentsFrame.width + indent + 3), y: -5, width: 2, height: contentsFrame.height - 5)//rectAt(caretIndex: caretIndex)
        let layer = self.cursorLayer

        layer.shapeLayer.fillColor = enabled ? cursorColor.cgColor : disabledColor.cgColor
        layer.layer.isHidden = !on
        layer.shapeLayer.path = CGPath(rect: cursorRect, transform: nil)
    }

    func updateFocus() {
        guard let imageLayer = layers["image"] else { return }

        imageLayer.layer.sublayers?.forEach { l in
            l.removeFromSuperlayer()
        }
        guard isFocused else {
            imageLayer.layer.mask = nil
            return
        }
        let bounds = imageLayer.bounds.insetBy(dx: -3, dy: -3)
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
        borderLayer.position = CGPoint(x: indent + childInset + imageLayer.layer.bounds.width / 2, y: imageLayer.layer.bounds.height / 2)
        borderLayer.mask = mask
        imageLayer.layer.addSublayer(borderLayer)
    }

    override func setLayout(_ frame: NSRect) {
        super.setLayout(frame)
    }
    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }
}
