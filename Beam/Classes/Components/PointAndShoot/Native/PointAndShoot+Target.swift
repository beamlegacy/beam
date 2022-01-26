//
//  PointAndShoot+Target.swift
//  Beam
//
//  Created by Stef Kors on 30/08/2021.
//

import Foundation
import BeamCore

extension PointAndShoot {
    /// Describes a target area as part of a Shoot group
    struct Target {
        /// ID of the target
        var id: String
        /// Rectangle Area of the target
        var rect: NSRect
        /// Point location of the mouse. It's used to draw the ShootCardPicker location.
        /// It's `x` and `y` location is relative to the top left corner of the area
        var mouseLocation: NSPoint
        /// HTML string of the targeted element
        var html: String
        /// Decides if ui applies animations
        var animated: Bool
        /// Translates target for scaling and positioning of frame
        func translateTarget(_ xDelta: CGFloat = 0, _ yDelta: CGFloat = 0, scale: CGFloat) -> Target {
            let newRect = NSRect(
                x: (rect.minX + xDelta) * scale,
                y: (rect.minY + yDelta) * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            let newLocation = NSPoint(
                x: (mouseLocation.x + xDelta) * scale,
                y: (mouseLocation.y + yDelta) * scale
            )
            return Target(id: id, rect: newRect, mouseLocation: newLocation, html: html, animated: animated)
        }
    }

    /// Creates initial Point and Shoot target
    /// - Parameters:
    ///   - rect: area of target to be drawn
    ///   - id: id of html element
    ///   - href: url location of target
    ///   - html: html of Target
    ///   - animated: should animate or not
    /// - Returns: Translated target
    func createTarget(_ id: String, _ rect: NSRect, _ html: String, _ href: String, _ animated: Bool) -> Target {
        return Target(
            id: id,
            rect: rect,
            mouseLocation: mouseLocation.clamp(rect),
            html: html,
            animated: animated
        )
    }

    func translateAndScaleTargetsIfNeeded(_ targets: [PointAndShoot.Target], _ href: String) -> [PointAndShoot.Target]? {
        guard let page = self.page,
              let view = page.webView else {
                  Logger.shared.logError("Webview is required to scale target correctly", category: .pointAndShoot)
                  return nil
              }
        let scale: CGFloat = view.zoomLevel()
        // We can reduce calculations for the MainWindowFrame
        let isDifferentUrl = href != page.url?.absoluteString
        guard isDifferentUrl || scale != 1 else {
            return nil
        }
        let offset: CGPoint
        if let webPositions = page.webPositions {
            offset = webPositions.viewportPosition(href: href)
        } else {
            Logger.shared.logError("webPositions is required to scale target correctly", category: .pointAndShoot)
            offset = .zero
        }
        return targets.map({ target in
            translateAndScaleTarget(target, xDelta: offset.x, yDelta: offset.y, scale: scale, isDifferentUrl: isDifferentUrl)
        })
    }

    func translateAndScaleTargetIfNeeded(_ target: PointAndShoot.Target, _ href: String) -> PointAndShoot.Target? {
        translateAndScaleTargetsIfNeeded([target], href)?.first
    }

    private func translateAndScaleTarget(_ target: PointAndShoot.Target,
                                         xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat, isDifferentUrl: Bool) -> PointAndShoot.Target {
        // We can reduce calculations for the MainWindowFrame
        guard isDifferentUrl else {
            // We can futher reduce calculations if the scale is 1
            guard scale != 1 else {
                return target
            }
            return target.translateTarget(0, 0, scale: scale)
        }
        return target.translateTarget(xDelta, yDelta, scale: scale)
    }
}
