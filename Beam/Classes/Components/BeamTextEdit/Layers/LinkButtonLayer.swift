//
//  LinkButtonLayer.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/04/2021.
//

import Foundation

class LinkButtonLayer: ButtonLayer {

    override init(_ name: String, _ layer: CALayer,
                  activated: @escaping () -> Void = { },
                  hovered: @escaping (Bool) -> Void = { _ in }) {

        super.init(name, layer, hovered: hovered)
        self.activated = activated

        mouseDown = { [unowned self] _ -> Bool in
            self.pressed = true
            handleBackgroundUi()
            return true
        }
        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if p {
                self.activated()
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
