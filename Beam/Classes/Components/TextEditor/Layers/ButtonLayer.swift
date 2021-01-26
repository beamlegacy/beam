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

    init(_ name: String, _ layer: CALayer, mouseXPosition: CGFloat = 0,
         activated: @escaping () -> Void = { },
         hovered: @escaping (Bool) -> Void = { _ in }) {

        self.activated = activated
        super.init(name: name, layer: layer)
        self.mouseXPosition = mouseXPosition

        mouseDown = { [unowned self] _ -> Bool in
            self.pressed = true
            return true
        }
        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(NSPoint(x: mouseXPosition + info.position.x, y: info.position.y))
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
    }
}
