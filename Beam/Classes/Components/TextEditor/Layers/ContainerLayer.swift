//
//  ContainerLayer.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 25/01/2021.
//

import Foundation
class ContainerLayer: Layer {
    var activated: () -> Void

    init(_ name: String, _ layer: CALayer, activated: @escaping () -> Void = { }) {
        self.activated = activated
        super.init(name: name, layer: layer)
        mouseDragged = { _ -> Bool in
            print("hello world")
            return true
        }

    }

}
