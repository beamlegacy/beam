//
//  TextLinesDecorationLayer.swift
//  Beam
//
//  Created by Remi Santos on 01/06/2021.
//

import Foundation

class TextLinesDecorationLayer: CALayer {

    private let initialFrame = CGRect.zero
    private let decorationInset: CGFloat = 10

    var offset: CGFloat = 0
    var textLines: [TextLine]? {
        didSet {
            var rect = textLines?.reduce(CGRect.zero, { $0.union($1.frame) }) ?? initialFrame
            rect.origin.x += offset
            rect = rect.insetBy(dx: -decorationInset, dy: -decorationInset)
            CATransaction.disableAnimations {
                self.frame = rect
            }
        }
    }

    init(_ textLines: [TextLine]? = nil) {
        super.init()
        self.name = "lineDecoration"
        self.zPosition = -1
        self.textLines = textLines
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func removeAllSublayers() {
        sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    override func layoutSublayers() {
        NSAppearance.withAppAppearance {
            removeAllSublayers()
            guard let textLines = textLines, !textLines.isEmpty else { return }

            let textOrigin = CGPoint(x: decorationInset, y: decorationInset)

            var layers = [CALayer]()
            for textLine in textLines {
                let originY = textOrigin.y + textLine.frame.minY
                var offset = textOrigin.x + textLine.frame.minX
                var boxBackgroundRect: CGRect?
                var boxColor: NSColor?

                for run in textLine.runs {
                    var ascent = CGFloat(0)
                    var descent = CGFloat(0)
                    let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil))
                    let height = ascent + descent
                    let rect = computeRect(offset: offset, originY: originY, width: width, height: height)

                    if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] {
                        layers.append(contentsOf: decorate(with: attributes, rect: rect, boxBackgroundRect: &boxBackgroundRect, boxColor: &boxColor))
                    }
                    offset += CGFloat(width)
                }
                if let boxLayer = buildBoxBackgroundLayer(boxBackgroundRect, color: boxColor) {
                    layers.append(boxLayer)
                }
            }
            layers.forEach { addSublayer($0) }
        }
    }

    var lastAnimatedRect: CGRect?

    func buildBoxBackgroundLayer(_ rect: CGRect?, color: NSColor?, bumpAnimation: Bool = false) -> CAShapeLayer? {
        guard let rect = rect, let boxColor = color else { return nil }
        let path = NSBezierPath(roundedRect: CGRect(origin: .zero, size: rect.size), xRadius: 4, yRadius: 4).cgPath
        let layer = CAShapeLayer()
        layer.frame = rect
        layer.path = path
        layer.fillColor = BeamColor.Generic.background.nsColor.add(boxColor).cgColor

        if bumpAnimation {
            if let last = lastAnimatedRect, last == rect {
                return layer
            }

            let scaleUp = CABasicAnimation(keyPath: "transform.scale")
            scaleUp.fromValue = 1.0
            scaleUp.toValue = 1.3
            scaleUp.duration = 0.2
            scaleUp.timingFunction = CAMediaTimingFunction(name: .easeIn)

            let scaleDown = CABasicAnimation(keyPath: "transform.scale")
            scaleDown.fromValue = 1.3
            scaleDown.toValue = 1.0
            scaleDown.duration = 0.07
            scaleDown.beginTime = 0.2
            scaleDown.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let group = CAAnimationGroup()
            group.animations = [scaleUp, scaleDown]
            group.duration = 0.27

            layer.add(group, forKey: "bumpAnim")

            lastAnimatedRect = rect
        }

        return layer
    }

    private func computeRect(offset: CGFloat, originY: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        let inset: CGFloat = -4
        let rect = CGRect(x: offset, y: originY, width: width, height: height).insetBy(dx: inset, dy: inset)
        return rect
    }

    private func decorate(with attributes: [NSAttributedString.Key: Any],
                          rect: CGRect,
                          boxBackgroundRect: inout CGRect?,
                          boxColor: inout NSColor?) -> [CALayer] {
        var layers = [CALayer]()

        if let color = attributes[.boxBackgroundColor] as? NSColor {
            boxBackgroundRect = boxBackgroundRect?.union(rect) ?? rect
            boxColor = color
        } else if let color = attributes[.searchFoundBackground] as? NSColor {
            if let last = lastAnimatedRect, last == rect {
                lastAnimatedRect = nil
            }
            if let searchLayer = buildBoxBackgroundLayer(rect, color: color) {
                layers.append(searchLayer)
            }
        } else if let color = attributes[.searchCurrentResultBackground] as? NSColor {
            if let searchLayer = buildBoxBackgroundLayer(rect, color: color, bumpAnimation: true) {
                layers.append(searchLayer)
            }
        } else {
            if let boxLayer = buildBoxBackgroundLayer(boxBackgroundRect, color: boxColor) {
                layers.append(boxLayer)
            }
            boxBackgroundRect = nil
            boxColor = nil
        }

        return layers
    }
}
