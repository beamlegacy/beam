//
//  LayerRemoverAnimationDelegate.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 01/07/2021.
//

import Foundation

class LayerRemoverAnimationDelegate: NSObject, CAAnimationDelegate {

    private weak var layer: CALayer?

    init(with layer: CALayer) {
        self.layer = layer
        super.init()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        layer?.removeFromSuperlayer()
    }
}
