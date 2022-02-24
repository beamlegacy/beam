//
//  TextLineLayer.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2021.
//

import Foundation
import AppKit

class
TextLineLayer: CALayer {
    weak var textLine: TextLine?
    let debug = false

    init(_ textLine: TextLine) {
        self.textLine = textLine
        super.init()
        self.name = "line"
        self.frame = textLine.frame
        self.setNeedsDisplay()

        if debug {
            borderWidth = 1
            borderColor = NSColor.green.withAlphaComponent(0.5).cgColor
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        guard let textLine = textLine else { return }
        let firstLineBaseline = CGFloat(textLine.typographicBounds.ascent)
        ctx.textMatrix = CGAffineTransform.identity
        ctx.translateBy(x: 0, y: firstLineBaseline)

        NSAppearance.withAppAppearance {
            textLine.draw(ctx, translate: false)
        }
    }

    // Init Overrides:
    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
}
