//
//  Layer.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/01/2021.
//

import Foundation
import Combine
import AppKit
import AVFoundation

@objc class Layer: NSAccessibilityElement, CALayerDelegate, MouseHandler {
    var name: String {
        didSet {
            layer.name = name
            setAccessibilityLabel(name)
        }
    }
    var layer: CALayer
    var hovering: Bool = false
    var cursor: NSCursor?
    weak var widget: Widget?

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
    private let displayHandler: (CALayer) -> Void
    var layout: () -> Void

    /// Layer adds a compositing filter to the CALayer (dark screen, light multiply) and update it on appearance change
    /// Setting this property to false will prevent the addition and update of this filter to allow its management elsewhere
    var addDefaultCompositingFilter = true

    /// The app appearance at the time UI elements using dynamic colors were last updated.
    private var currentAppearance: NSAppearance?

    init(name: String,
         layer: CALayer,
         down: @escaping MouseBlock = { _ in false },
         up: @escaping MouseBlock = { _ in false },
         moved: @escaping MouseBlock = { _ in false },
         dragged: @escaping MouseBlock = { _ in false },
         hovered: @escaping (Bool) -> Void = { _ in },
         display: @escaping (CALayer) -> Void = { _ in },
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
        self.displayHandler = display
        self.layout = layout

        super.init()

        if layer.delegate == nil {
            layer.delegate = self
        }

        setAccessibilityRole(.button)
        setAccessibilityLabel(name)
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
        get {
            layer.frame
        }
        set {
            layer.frame = newValue.rounded()
        }
    }

    override func accessibilityFrameInParentSpace() -> NSRect {
        if let parent = layer.superlayer, let widget = widget {
            let parentRect = parent.frame
            let rect = layer.convert(bounds, to: parent)
            let actualY = parentRect.height - rect.maxY
            let correctedRect = NSRect(origin: CGPoint(x: rect.origin.x - widget.contentsFrame.origin.x, y: actualY - widget.contentsFrame.origin.y), size: rect.size)
            return correctedRect
        }

        return frame
    }

    var bounds: NSRect {
        CGRect(origin: CGPoint(), size: frame.size)
    }

    func contains(_ position: NSPoint, ignoreX: Bool = false) -> Bool {
        if ignoreX {
            return bounds.minY <= position.y && position.y < bounds.maxY
        }
        return bounds.contains(position)
    }

    func display(_ layer: CALayer) {
        displayHandler(layer)
    }

    func layoutSublayers(of layer: CALayer) {
        assert(layer == self.layer)
        layout()
    }

    func handleMouseMoved(_ mouseInfo: MouseInfo) -> Bool {
        handleHover(contains(mouseInfo.position))
        return mouseMoved(mouseInfo)
    }

    /// This method is called when this layer is added to a widget, and when the app appearance has changed.
    ///
    /// You can override this method to set all UI elements using dynamic colors.
    ///
    /// If you override this method, call this method on super at some point in your implementation in case a
    /// superclass also overrides this method.
    func updateColors() {
        if addDefaultCompositingFilter {
            self.layer.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
        }
    }

    final func updateColorsIfNeeded() {
        // Stop if appearance has not changed since last pass
        guard currentAppearance == nil || (currentAppearance != NSApp.effectiveAppearance) else { return }
        updateColors()
        currentAppearance = NSApp.effectiveAppearance
    }

    var contentsScale: CGFloat {
        get { self.layer.contentsScale }
        set {
            guard newValue != contentsScale else { return }
            self.layer.deepContentsScale = newValue
        }
    }
}

extension Layer {

    static func icon(named: String, size: CGSize? = nil) -> CALayer {
        let iconLayer = CALayer()
        let image = NSImage(named: named)
        let maskLayer = CALayer()
        maskLayer.contents = image
        iconLayer.mask = maskLayer
        iconLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size ?? image?.size ?? CGSize(width: 20, height: 20)).rounded()
        maskLayer.frame = iconLayer.bounds
        return iconLayer
    }

    static func icon(named: String, color: NSColor, size: CGSize? = nil) -> CALayer {
        let layer = Layer.icon(named: named, size: size)
        layer.backgroundColor = color.cgColor
        return layer
    }

    static func text(_ label: String, color: NSColor = BeamColor.Generic.text.nsColor, size: CGFloat = 12) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = label
        textLayer.foregroundColor = color.cgColor
        textLayer.fontSize = size
        textLayer.frame = CGRect(origin: CGPoint(), size: textLayer.preferredFrameSize()).rounded()

        return textLayer
    }

    static func text(named: String, _ label: String, color: NSColor = BeamColor.Generic.text.nsColor, size: CGFloat = 12) -> Layer {
        Layer(name: named, layer: text(label, color: color, size: size))
    }

    static func image(image: NSImage, size: CGSize? = nil) -> CALayer {
        let imageLayer = CALayer()
        imageLayer.contents = image
        imageLayer.frame = CGRect(origin: .zero, size: size ?? image.size).rounded()
        imageLayer.position = .zero
        imageLayer.anchorPoint = .zero
        return imageLayer
    }

    static func image(named: String, image: NSImage, size: CGSize? = nil) -> Layer {
        Layer(name: named, layer: Self.image(image: image, size: size))
    }

    static func animatedImage(imageData: Data, size: CGSize? = nil) -> CALayer? {
        guard let imageLayer = animationForImageData(with: imageData) else { return nil }
        imageLayer.frame = CGRect(origin: .zero, size: size ?? imageLayer.bounds.size).rounded()
        imageLayer.position = .zero
        imageLayer.anchorPoint = .zero
        return imageLayer
    }

    static func animatedImage(named: String, imageData: Data, size: CGSize? = nil) -> Layer? {
        guard let anim = animatedImage(imageData: imageData, size: size) else { return nil }
        return Layer(name: named, layer: anim)
    }

    fileprivate static func animationForImageData(with data: Data) -> CALayer? {
        let layer = GIFAnimatedLayer(data: data)
        layer?.startAnimating()
        return layer
    }

    func accessibilityTitle(for layer: CALayer) -> String? {
        guard let textLayer = layer as? CATextLayer else { return nil }
        if let attrString = textLayer.string as? NSAttributedString {
            return attrString.string
        } else if let string = textLayer.string as? String {
            return string
        }

        return nil
    }

    func sublayersAccessibilityTitle() -> String? {
        if let sublayers = layer.sublayers {
            for layer in sublayers where layer is CATextLayer {
                if let label = accessibilityTitle(for: layer) {
                    return label
                }
            }
        }

        return nil
    }

    override func accessibilityTitle() -> String? {
        return accessibilityTitle(for: layer) ?? sublayersAccessibilityTitle() ?? super.accessibilityTitle()
    }

    override var description: String {
        "\(name) - layer = \(layer)"
    }
}
