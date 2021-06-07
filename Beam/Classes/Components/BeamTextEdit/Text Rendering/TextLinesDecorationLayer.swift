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
            self.setNeedsDisplay()
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

    override func draw(in context: CGContext) {
        guard let textLines = textLines, !textLines.isEmpty else { return }
        context.saveGState()

        context.translateBy(x: decorationInset, y: decorationInset)
        let firstLineBaseline = CGFloat(textLines.first?.typographicBounds.ascent ?? 0)
        context.translateBy(x: 0, y: firstLineBaseline)
        context.scaleBy(x: 1, y: -1)
        for textLine in textLines {

            let originY = -textLine.frame.minY
            var offset = textLine.frame.minX//CGFloat(0)
            var boxBackgroundRect: CGRect?
            var boxColor: NSColor?

            for run in textLine.runs {
                var ascent = CGFloat(0)
                var descent = CGFloat(0)
                let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil))
                if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] {
                    if let color = attributes[.boxBackgroundColor] as? NSColor {
                        let inset: CGFloat = -CGFloat(roundf(Float(ascent / 5.0)))
                        let rect = CGRect(x: offset, y: originY + inset, width: width, height: ascent).insetBy(dx: inset, dy: inset)
                        boxBackgroundRect = boxBackgroundRect?.union(rect) ?? rect
                        boxColor = color
                    } else {
                        drawFinishedBoxBackgroundRect(boxBackgroundRect, color: boxColor, in: context)
                        boxBackgroundRect = nil
                        boxColor = nil
                    }
                }
                offset += CGFloat(width)
            }
            drawFinishedBoxBackgroundRect(boxBackgroundRect, color: boxColor, in: context)
//            context.translateBy(x: 0, y: -textLine.frame.maxY)
        }
        context.restoreGState()
    }

    func drawFinishedBoxBackgroundRect(_ rect: CGRect?, color: NSColor?, in context: CGContext) {
        guard let rect = rect, let boxColor = color else { return }
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).cgPath
        context.addPath(path)
        context.setFillColor(boxColor.cgColor)
        context.fillPath()
    }
}
