//
//  TableRowView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation
import SwiftUI

class BeamTableRowView: NSTableRowView {

    var onHover: ((Bool) -> Void)?
    var highlightOnSelection: Bool = true
    private var isHovering: Bool = false
    private var extraLeftHover: CGFloat = 32

    override func drawSelection(in dirtyRect: NSRect) {
        if highlightOnSelection && selectionHighlightStyle != .none {
            let selectionRect = bounds
            BeamColor.Bluetiful.nsColor.withAlphaComponent(0.1).setFill()
            let selectionPath = NSBezierPath(rect: selectionRect)
            selectionPath.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isHovering && !isSelected {
            let selectionRect = bounds
            BeamColor.Bluetiful.nsColor.withAlphaComponent(0.05).setFill()
            let selectionPath = NSBezierPath(rect: selectionRect)
            selectionPath.fill()
        }
        BeamColor.Generic.separator.nsColor.setFill()
        let linePath = NSBezierPath(rect: NSRect(origin: CGPoint(x: dirtyRect.origin.x, y: dirtyRect.height - 1), size: CGSize(width: dirtyRect.width, height: 1)))
        linePath.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        var rect = bounds
        let x = -extraLeftHover
        rect.origin.x = x
        rect.size.width += -x
        let newArea = NSTrackingArea(
            rect: rect,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        )
        self.addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        onHover?(true)
        setNeedsDisplay(bounds)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        onHover?(false)
        setNeedsDisplay(bounds)
    }

    func offsetChanged() {
        isHovering = false
        setNeedsDisplay(bounds)
    }
}
