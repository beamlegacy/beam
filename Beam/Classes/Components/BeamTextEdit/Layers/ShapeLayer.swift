//
//  ShapeLayer.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2021.
//

import Foundation

class ShapeLayer: Layer {
    var shapeLayer: CAShapeLayer {
        layer as! CAShapeLayer
    }

    init(name: String, down: @escaping Layer.MouseBlock = { _ in false }, up: @escaping Layer.MouseBlock = { _ in false }, moved: @escaping Layer.MouseBlock = { _ in false }, dragged: @escaping Layer.MouseBlock = { _ in false }, hovered: @escaping (Bool) -> Void = { _ in }, layout: @escaping () -> Void = { }) {
        super.init(name: name, layer: CAShapeLayer(), down: down, up: up, moved: moved, dragged: dragged, hovered: hovered, layout: layout)
    }
}
