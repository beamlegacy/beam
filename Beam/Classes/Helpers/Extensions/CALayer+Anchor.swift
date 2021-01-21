//
//  CALayer+Anchor.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 21/01/2021.
//

import Foundation

extension CALayer {

    private func moveAnchorToPoint(point: CGPoint) {
        if point.equalTo(anchorPoint) { return }

        var newPoint = CGPoint(x: bounds.size.width * point.x, y: bounds.size.height * point.y)
        var oldPoint = CGPoint(x: bounds.size.width * anchorPoint.x, y: bounds.size.height * anchorPoint.y)

        newPoint = newPoint.applying(affineTransform())
        oldPoint = oldPoint.applying(affineTransform())

        var position = self.position

        position.x += newPoint.x - oldPoint.x
        position.y += newPoint.y - oldPoint.y

        self.position = position
        anchorPoint = point
    }

    func anchorToCenter() {
        moveAnchorToPoint(point: CGPoint(x: 0.5, y: 0.5))
    }

}
