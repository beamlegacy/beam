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
    var activated: () -> Void

    init(_ name: String, _ layer: CALayer,
         activated: @escaping () -> Void = { },
         hovered: @escaping (Bool) -> Void = { _ in }) {

        self.activated = activated
        super.init(name: name, layer: layer)

        mouseDown = { [unowned self] _ -> Bool in
            self.pressed = true
            return true
        }
        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if p {
                self.activated()
            }
            self.pressed = false
            return true
        }
        mouseDragged = { [unowned self] info -> Bool in
            self.pressed = layer.contains(info.position)
            return true
        }
        hover = { isHover in
            hovered(isHover)
        }

        setAccessibilityRole(.button)
    }

    override func accessibilityPerformPress() -> Bool {
        guard !layer.isHidden else { return false }
        activated()
        return true
    }

}
