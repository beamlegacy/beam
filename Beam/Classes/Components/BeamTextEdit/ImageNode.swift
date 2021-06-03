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

    override init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)

        setupImage()

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)
    }

    override init(editor: BeamTextEdit, element: BeamElement) {
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
            let width = imageSize.width > available ? available : imageSize.width
            let height = (width / imageSize.width) * imageSize.height
            contentsFrame = NSRect(x: indent, y: 0, width: width, height: childInset + height)

            if let imageLayer = layers["image"] {
                imageLayer.layer.position = CGPoint(x: indent + childInset, y: 0)
                imageLayer.layer.bounds = CGRect(origin: imageLayer.frame.origin, size: CGSize(width: width, height: height))

                updateFocus()
            }
            computedIdealSize = contentsFrame.size
            computedIdealSize.width = frame.width

            invalidatedRendering = false
        }

        if open && selfVisible {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
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

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }
}
