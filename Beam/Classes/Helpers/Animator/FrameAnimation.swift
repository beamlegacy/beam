//
//  FrameAnimation.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/11/2020.
//

import Foundation

class FrameAnimation: BeamAnimation {
    private var start: NSRect
    private var destination: NSRect
    @Published var current: NSRect

    init(from: NSRect, to: NSRect, in duration: CFTimeInterval = 1) {
        start = from
        destination = to
        current = start

        super.init(duration: duration)
    }

    override func update(_ value: CFTimeInterval) {
        let v = CGFloat(value)
        current = NSRect(x: interpolate(start.minX, destination.minX, v),
                         y: interpolate(start.minY, destination.minY, v),
                         width: interpolate(start.width, destination.width, v),
                         height: interpolate(start.height, destination.height, v))
    }
}
