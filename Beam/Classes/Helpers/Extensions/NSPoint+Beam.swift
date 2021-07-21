//
//  NSPoint+Beam.swift
//  Beam
//
//  Created by Stef Kors on 15/07/2021.
//

import Foundation

extension NSPoint {
    func clamp(_ rect: NSRect) -> NSPoint {
        let point = self
        let x: CGFloat = point.x.clamp(rect.minX, rect.maxX)
        let y: CGFloat = point.y.clamp(rect.minY, rect.maxY)
        return NSPoint(x: x, y: y)
    }
}
