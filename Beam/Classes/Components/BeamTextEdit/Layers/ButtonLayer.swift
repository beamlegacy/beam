//
//  ButtonLayer.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/01/2021.
//

import Foundation
import AppKit
import Combine

class ButtonLayer: Layer {
    @Published var pressed: Bool = false
    
    var activated: (_ mouseInfo: MouseInfo?) -> Void

    init(_ name: String, _ layer: CALayer,
         activated: @escaping (_ mouseInfo: MouseInfo?) -> Void = { _ in },
         hovered: @escaping (Bool) -> Void = { _ in }) {
        self.activated = activated
        super.init(name: name, layer: layer, hovered: hovered)

        mouseDown = { [unowned self] info -> Bool in
            if info.rightMouse, layer.contains(info.position) {
                activated(info)
            }
            self.pressed = true
            return true
        }
        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if !info.rightMouse, p {
                self.activated(info)
            }
            self.pressed = false
            return true
        }
        mouseDragged = { [unowned self] info -> Bool in
            self.pressed = layer.contains(info.position)
            return true
        }
        setAccessibilityRole(.button)
    }

    override func accessibilityPerformPress() -> Bool {
        guard !layer.isHidden else { return false }
        activated(nil)
        return true
    }
}
