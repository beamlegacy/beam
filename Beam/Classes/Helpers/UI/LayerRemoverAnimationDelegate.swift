//
//  LayerRemoverAnimationDelegate.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 01/07/2021.
//

import Foundation

class LayerRemoverAnimationDelegate: NSObject, CAAnimationDelegate {

    private weak var layer: CALayer?
    private var callback: ((Bool) -> Void)?

    init(with layer: CALayer, completion: ((Bool) -> Void)? = nil) {
        self.layer = layer
        self.callback = completion
        super.init()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        layer?.removeFromSuperlayer()
        callback?(flag)
    }
}
