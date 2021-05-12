//
//  Layer.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/01/2021.
//

import Foundation
import Combine
import AppKit

class Layer: NSAccessibilityElement, CALayerDelegate, MouseHandler {
    var name: String {
        didSet {
            layer.name = name
            setAccessibilityLabel(name)
        }
    }
    var layer: CALayer
    var hovering: Bool = false
    var cursor: NSCursor?

    typealias MouseBlock = (MouseInfo) -> Bool
    var mouseDown: MouseBlock
    var mouseUp: MouseBlock
    var mouseMoved: MouseBlock
    var mouseDragged: MouseBlock
    var hovered: (Bool) -> Void
    func handleHover(_ value: Bool) {
        if hovering != value {
            hovered(value)
            hovering = value
            // layer.borderColor = hovered ? NSColor.red.cgColor : nil
            // layer.borderWidth = hovered ? 2 : 0
        }
    }
    var layout: () -> Void

    init(name: String,
         layer: CALayer,
         down: @escaping MouseBlock = { _ in false },
         up: @escaping MouseBlock = { _ in false },
         moved: @escaping MouseBlock = { _ in false },
         dragged: @escaping MouseBlock = { _ in false },
         hovered: @escaping (Bool) -> Void = { _ in },
         layout: @escaping () -> Void = { }
    ) {
        self.name = name
        layer.name = layer.name ?? name
        self.layer = layer
        self.mouseDown = down
        self.mouseUp = up
        self.mouseMoved = moved
        self.mouseDragged = dragged
        self.hovered = hovered
        self.layout = layout

        super.init()

        if layer.delegate == nil {
            layer.delegate = self
        }

        setAccessibilityRole(.none)
    }

    deinit {
        layer.removeFromSuperlayer()
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
            setAccessibilityFrameInParentSpace(newValue)
        }
        get {
            layer.frame
        }
    }

    var bounds: NSRect {
        CGRect(origin: CGPoint(), size: frame.size)
    }

    func contains(_ position: NSPoint) -> Bool {
        bounds.contains(position)
    }

    func layoutSublayers(of layer: CALayer) {
        assert(layer == self.layer)
        layout()
    }

    func handleMouseMoved(_ mouseInfo: MouseInfo) -> Bool {
        handleHover(contains(mouseInfo.position))
        return mouseMoved(mouseInfo)
    }

    func set(_ contentsScale: CGFloat) {
        self.layer.contentsScale = contentsScale
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

    static func text(_ label: String, color: NSColor = BeamColor.Generic.text.nsColor, size: CGFloat = 12) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = label
        textLayer.foregroundColor = color.cgColor
        textLayer.fontSize = size
        textLayer.frame = CGRect(origin: CGPoint(), size: textLayer.preferredFrameSize())

        return textLayer
    }

    static func text(named: String, _ label: String, color: NSColor = BeamColor.Generic.text.nsColor, size: CGFloat = 12) -> Layer {
        Layer(name: named, layer: text(label, color: color, size: size))
    }

    static func image(image: NSImage, size: CGSize? = nil) -> CALayer {
        let imageLayer = CALayer()
        imageLayer.contents = image
        imageLayer.frame = CGRect(origin: .zero, size: size ?? image.size)
        imageLayer.position = .zero
        imageLayer.anchorPoint = .zero
        return imageLayer
    }

    static func image(named: String, image: NSImage, size: CGSize? = nil) -> Layer {
        Layer(name: named, layer: Self.image(image: image, size: size))
    }

}
