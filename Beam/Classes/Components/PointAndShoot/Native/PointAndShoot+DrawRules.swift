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
        let translatedTarget = translateAndScaleTargetIfNeeded(target, href) ?? target
        let graceDistance: CGFloat = -40
        let graceArea: NSRect = translatedTarget.rect.insetBy(dx: graceDistance, dy: graceDistance)
        return graceArea.contains(mouse)
    }

    /// Checks if target is 120% taller or 110% wider than window frame.
    /// - Parameter target: Target to check
    /// - Returns: true if either width or height is largeey
    func isLargeTargetArea(_ target: Target) -> Bool {
        guard let page = self.page else { return false }
        let yPercent = (100 / page.frame.height) * target.rect.height
        let yIsLarge = yPercent > 120

        let xPercent = (100 / page.frame.width) * target.rect.width
        let xIsLarge = xPercent > 110
        return yIsLarge || xIsLarge
    }
}
