//
//  TextLayer.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 25/01/2021.
//

import Foundation

class TextLayer: Layer {

    init(_ label: String, color: NSColor = NSColor.editorTextColor, size: CGFloat = 12) {
        super.init(name: label, layer: Layer.text(label, color: color, size: size))
    }

}
