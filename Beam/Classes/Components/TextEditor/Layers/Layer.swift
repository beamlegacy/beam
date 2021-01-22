//
//  Layer.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/01/2021.
//

import Foundation
import Combine
import AppKit

class Layer: NSObject, CALayerDelegate {
    var name: String
    var layer: CALayer
    var hovered: Bool = false

    typealias MouseBlock = (MouseInfo) -> Bool
    var mouseDown: MouseBlock
    var mouseUp: MouseBlock
    var mouseMoved: MouseBlock
    var mouseDragged: MouseBlock
    var hover: (Bool) -> Void
    func handleHover(_ value: Bool) {
        if hovered != value {
            hover(value)
            hovered = value
        }
    }
    var layout: () -> Void

    init(name: String,
         layer: CALayer,
         down: @escaping MouseBlock = { _ in false },
         up: @escaping MouseBlock = { _ in false },
         moved: @escaping MouseBlock = { _ in false },
         dragged: @escaping MouseBlock = { _ in false },
         hover: @escaping (Bool) -> Void = { _ in },
         layout: @escaping () -> Void = { }
    ) {
        self.name = name
        self.layer = layer
        self.mouseDown = down
        self.mouseUp = up
        self.mouseMoved = moved
        self.mouseDragged = dragged
        self.hover = hover
        self.layout = layout

        super.init()

        if layer.delegate == nil {
            layer.delegate = self
        }
    }

    func invalidate() {
        layer.setNeedsDisplay()
    }

    func invalidateLayout() {
        layer.setNeedsLayout()
    }

    var frame: NSRect {
        set {
            layer.frame = newValue
        }
        get {
            layer.frame
        }
    }

    var bounds: NSRect {
        CGRect(origin: CGPoint(), size: frame.size)
    }

    var position: NSPoint {
        set {
            layer.position = newValue
        }
        get {
            layer.position
        }
    }

    func contains(_ mouseInfo: MouseInfo) -> Bool {
        bounds.contains(mouseInfo.position)
    }

    func layoutSublayers(of layer: CALayer) {
        assert(layer == self.layer)
        layout()
    }

    func handleMouseMoved(_ mouseInfo: MouseInfo) -> Bool {
        handleHover(contains(mouseInfo))
        return mouseMoved(mouseInfo)
    }
}

extension Layer {
    static func icon(named: String, color: NSColor, size: CGSize? = nil) -> CALayer {
        let iconLayer = CALayer()
        let image = NSImage(named: named)
        let maskLayer = CALayer()
        maskLayer.contents = image
        iconLayer.mask = maskLayer
        iconLayer.backgroundColor = color.cgColor
        iconLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size ?? image?.size ?? CGSize(width: 20, height: 20))
        maskLayer.frame = iconLayer.bounds
        return iconLayer
    }

    static func text(_ label: String, color: NSColor = NSColor.editorTextColor, size: CGFloat = 12) -> CALayer {
        let textLayer = CATextLayer()
        textLayer.string = label
        textLayer.foregroundColor = NSColor.editorIconColor.cgColor
        textLayer.fontSize = size
        textLayer.frame = CGRect(origin: CGPoint(), size: textLayer.preferredFrameSize())

        return textLayer
    }

    static func text(named: String, _ label: String, color: NSColor = NSColor.editorTextColor, size: CGFloat = 12) -> Layer {
        Layer(name: named, layer: text(label, color: color, size: size))
    }
}
