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
        get {
            layer.frame
        }
        set {
            layer.frame = newValue
            setAccessibilityFrameInParentSpace(newValue)
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

    var contentsScale: CGFloat {
        get {
            self.layer.contentsScale
        }
        set {
            self.layer.deepContentsScale = contentsScale
        }
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

    static func animatedImage(imageData: Data, size: CGSize? = nil) -> CALayer? {
        guard let imageLayer = animationForImageData(with: imageData) else { return nil }
        imageLayer.frame = CGRect(origin: .zero, size: size ?? imageLayer.bounds.size)
        imageLayer.position = .zero
        imageLayer.anchorPoint = .zero
        return imageLayer
    }

    static func animatedImage(named: String, imageData: Data, size: CGSize? = nil) -> Layer? {
        guard let anim = animatedImage(imageData: imageData, size: size) else { return nil }
        return Layer(name: named, layer: anim)
    }

    fileprivate static func animationForImageData(with data: Data) -> CALayer? {
        let layer = CALayer()
        let data = data as CFData
        let animation = CAKeyframeAnimation(keyPath: "contents")
        var frames = [CGImage]()
        var delayTimes = [NSNumber]()
        var totalTime: Float = 0.0
        let imageSource = CGImageSourceCreateWithData(data, nil)
        // get frame count
        let frameCount = CGImageSourceGetCount(imageSource!)
        guard frameCount > 1 else { return nil }
        for i in 0..<frameCount {
            // get each frame
            let frame = CGImageSourceCreateImageAtIndex(imageSource!, i, nil)
            if let frame = frame {
                frames.append(frame)
            }
            // get image info with each frame
            if let dict = CGImageSourceCopyPropertiesAtIndex(imageSource!, i, nil) as? [CFString: AnyObject] {
                // get image size
                if let imageWidth = (dict[kCGImagePropertyPixelWidth] as? NSNumber)?.floatValue,
                   let imageHeight = (dict[kCGImagePropertyPixelHeight] as? NSNumber)?.floatValue {
                    layer.frame = NSRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
                }
                if let imageDict = dict[kCGImagePropertyGIFDictionary],
                   let value = imageDict[kCGImagePropertyGIFDelayTime] as? NSNumber {
                    delayTimes.append(value)
                    totalTime += (((imageDict[kCGImagePropertyGIFDelayTime] as? NSNumber)?.floatValue)!)
                }
            }
        }
        var times = [AnyHashable](repeating: 0, count: 3)
        var currentTime: Float = 0
        let count: Int = delayTimes.count
        for i in 0..<count {
            times.append(NSNumber(value: Float((currentTime / totalTime))))
            currentTime += delayTimes[i].floatValue
        }
        var images = [AnyHashable](repeating: 0, count: 3)
        for i in 0..<count {
            images.append(frames[i])
        }
        animation.keyTimes = times as? [NSNumber]
        animation.values = images
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = CFTimeInterval(totalTime)
        animation.repeatCount = Float.infinity
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: "contents")
        return layer
    }
}
