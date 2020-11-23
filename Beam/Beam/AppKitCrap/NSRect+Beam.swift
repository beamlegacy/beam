//
//  NSRect+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation

public extension NSRect {
    init(x: Float, y: Float, width: Float, height: Float) {
        self.init()
        origin = CGPoint(x: CGFloat(x), y: CGFloat(y))
        size = CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    func rounded() -> NSRect {
        let left = self.minX.rounded(.toNearestOrEven)
        let right = self.maxX.rounded(.toNearestOrEven)
        let top = self.minY.rounded(.toNearestOrEven)
        let bottom = self.maxY.rounded(.toNearestOrEven)

        return NSRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
