//
//  PointAndShoot+Target.swift
//  Beam
//
//  Created by Stef Kors on 30/08/2021.
//

import Foundation

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
        /// Plain text string of the targeted content
        var text: String?
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
            return Target(id: id, rect: newRect, mouseLocation: newLocation, html: html, text: text, animated: animated)
        }
    }

    /// Creates initial Point and Shoot target
    /// - Parameters:
    ///   - rect: area of target to be drawn
    ///   - id: id of html element
    ///   - href: url location of target
    /// - Returns: Translated target
    func createTarget(_ id: String, _ rect: NSRect, _ html: String, _ text: String = "", _ href: String, _ animated: Bool) -> Target {
        return Target(
            id: id,
            rect: rect,
            mouseLocation: mouseLocation.clamp(rect),
            html: html,
            text: text,
            animated: animated
        )
    }

    func translateAndScaleTarget(_ target: PointAndShoot.Target, _ href: String) -> PointAndShoot.Target {
        guard let view = page.webView else {
            fatalError("Webview is required to scale target correctly")
        }
        let scale: CGFloat = webPositions.scale * view.zoomLevel()
        // We can reduce calculations for the MainWindowFrame
        guard href != page.url?.absoluteString else {
            // We can futher reduce calculations if the scale is 1
            guard scale != 1 else {
                return target
            }
            return target.translateTarget(0, 0, scale: scale)
        }

        let frameOffsetX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.x).reduce(0, +)
        let frameOffsetY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.y).reduce(0, +)
        let frameScrollX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollX)
        let frameScrollY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollY)
        let xDelta = frameOffsetX - frameScrollX.reduce(0, +)
        let yDelta = frameOffsetY - frameScrollY.reduce(0, +)

        return target.translateTarget(xDelta, yDelta, scale: scale)
    }
}
