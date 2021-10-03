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
            self.updateSubLayers()
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

    private func updateSubLayers() {
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
                    if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] {
                        if let color = attributes[.boxBackgroundColor] as? NSColor {
                            let inset: CGFloat = -4
                            let rect = CGRect(x: offset, y: originY, width: width, height: height).insetBy(dx: inset, dy: inset)
                            boxBackgroundRect = boxBackgroundRect?.union(rect) ?? rect
                            boxColor = color
                        } else {
                            if let boxLayer = buildBoxBackgroundLayer(boxBackgroundRect, color: boxColor) {
                                layers.append(boxLayer)
                            }
                            boxBackgroundRect = nil
                            boxColor = nil
                        }
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

    func buildBoxBackgroundLayer(_ rect: CGRect?, color: NSColor?) -> CAShapeLayer? {
        guard let rect = rect, let boxColor = color else { return nil }
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).cgPath
        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = BeamColor.Generic.background.nsColor.add(boxColor).cgColor
        return layer
    }

}
