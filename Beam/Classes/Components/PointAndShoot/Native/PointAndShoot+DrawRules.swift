//
//  PointAndShoot+DrawRules.swift
//  Beam
//
//  Created by Stef Kors on 16/07/2021.
//

import Foundation
import BeamCore

extension PointAndShoot {
    /// Checks if target and mouse location overlap. The rect is expanded with a 40px grace distance as a UX improvement.
    /// - Parameter target: Target to check
    /// - Returns: true if target rect contains mouselocation
    func hasGraceRectAndMouseOverlap(_ target: Target, _ href: String, _ mouse: NSPoint) -> Bool {
        let translatedTarget = translateAndScaleTarget(target, href)
        let graceDistance: CGFloat = -80
        let graceArea: NSRect = translatedTarget.rect.insetBy(dx: graceDistance, dy: graceDistance)
        return graceArea.contains(mouse)
    }

    /// Checks if target is 150% taller than window frame.
    /// - Parameter target: Target to check
    /// - Returns: true if target is tall
    func isLargeTargetArea(_ target: Target) -> Bool {
        let yPercent = (100 / page.frame.height) * target.rect.height
        let yIsLarge = yPercent > 150
        return yIsLarge
    }
}
