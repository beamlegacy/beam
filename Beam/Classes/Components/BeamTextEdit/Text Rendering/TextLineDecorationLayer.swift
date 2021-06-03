//
//  TextLineDecorationLayer.swift
//  Beam
//
//  Created by Remi Santos on 01/06/2021.
//

import Foundation

class TextLineDecorationLayer: CALayer {
    weak var textLine: TextLine?

    private let decorationInset: CGFloat = 10
    init(_ textLine: TextLine) {
        self.textLine = textLine
        super.init()
        self.name = "lineDecoration"
        self.frame = textLine.bounds.insetBy(dx: -decorationInset, dy: -decorationInset)
        self.zPosition = -1
        self.setNeedsDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in context: CGContext) {
        guard let textLine = textLine else { return }
        context.saveGState()

        let firstLineBaseline = CGFloat(textLine.typographicBounds.ascent)
        context.translateBy(x: decorationInset, y: firstLineBaseline + decorationInset)
        context.scaleBy(x: 1, y: -1)

        var offset = CGFloat(0)
        for run in textLine.runs {
            var ascent = CGFloat(0)
            var descent = CGFloat(0)
            let width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil)
            if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] {

                if let color = attributes[.boxBackgroundColor] as? NSColor {
                    let inset: CGFloat = -CGFloat(roundf(Float(ascent / 5.0)))
                    let rect = CGRect(x: offset, y: inset * 2, width: CGFloat(width), height: ascent).insetBy(dx: inset, dy: inset)
                    let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).cgPath
                    context.addPath(path)
                    context.setFillColor(color.cgColor)
                    context.fillPath()
                }
            }
            offset += CGFloat(width)
        }
        context.restoreGState()
    }
}
