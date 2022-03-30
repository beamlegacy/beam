//
//  TextFrameLayer.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2021.
//

import Foundation

class TextFrameLayer: CALayer {
    let debug = false
    weak var textFrame: TextFrame?
    init(_ textFrame: TextFrame) {
        super.init()
        self.frame = CGRect(origin: textFrame.frame.origin, size: textFrame.frame.size)

        for line in textFrame.lines {
            let lineLayer = line.layer
            CATransaction.disableAnimations {
                addSublayer(lineLayer)
            }
        }

        if debug {
            borderWidth = 1
            borderColor = NSColor.blue.withAlphaComponent(0.5).cgColor
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Init Overrides:
    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }
}
