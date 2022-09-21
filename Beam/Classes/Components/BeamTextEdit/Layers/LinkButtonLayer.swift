//
//  LinkButtonLayer.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/04/2021.
//

import Foundation

class LinkButtonLayer: ButtonLayer {

    override init(_ name: String, _ layer: CALayer,
                  activated: @escaping (_ mouseInfo: MouseInfo?) -> Void = { _ in },
                  hovered: @escaping (Bool) -> Void = { _ in }) {

        super.init(name, layer, activated: activated, hovered: hovered)

        mouseDown = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if info.rightMouse, p {
                self.activated(info)
            }
            self.pressed = true
            handleBackgroundUi()
            return true
        }
        
        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if !info.rightMouse, p {
                self.activated(info)
            }
            self.pressed = false
            handleBackgroundUi()
            return true
        }
        mouseDragged = { [unowned self] info -> Bool in
            self.pressed = layer.contains(info.position)
            return true
        }
        self.cursor = .pointingHand
        setAccessibilityRole(.button)
    }

    func handleBackgroundUi() {
        self.layer.cornerRadius = self.pressed ? 3 : 0
        self.layer.backgroundColor = self.pressed ? BeamColor.LinkedSection.actionButtonBackgroundHover.cgColor : NSColor.clear.cgColor
    }

    override func updateColors() {
        super.updateColors()

        handleBackgroundUi()
    }

}
