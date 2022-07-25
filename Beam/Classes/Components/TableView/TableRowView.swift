//
//  TableRowView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation
import SwiftUI

class BeamTableRowView: NSTableRowView {

    var hasSeparator: Bool = true
    var onHover: ((BeamTableRowView, Bool) -> Void)?
    var highlightOnSelection: Bool = true
    private var isHovering: Bool = false
    private var extraLeftHover: CGFloat = 32

    private func drawHighlightBackground(selected: Bool, hovering: Bool) {
        guard selected || hovering else { return }
        let selectionRect = bounds
        if selected {
            BeamColor.Bluetiful.nsColor.withAlphaComponent(0.14).setFill()
        } else if hovering {
            BeamColor.Bluetiful.nsColor.withAlphaComponent(0.1).setFill()
        }
        let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
        selectionPath.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if highlightOnSelection && selectionHighlightStyle != .none {
            self.drawHighlightBackground(selected: true, hovering: isHovering)
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if !isSelected {
            self.drawHighlightBackground(selected: false, hovering: isHovering)
        }
        if hasSeparator {
            BeamColor.Generic.separator.nsColor.setFill()
            let linePath = NSBezierPath(rect: NSRect(origin: CGPoint(x: dirtyRect.origin.x, y: dirtyRect.height - 1), size: CGSize(width: dirtyRect.width, height: 1)))
            linePath.fill()
        }
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
        onHover?(self, true)
        setNeedsDisplay(bounds)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        onHover?(self, false)
        setNeedsDisplay(bounds)
    }

    func offsetChanged() {
        isHovering = false
        setNeedsDisplay(bounds)
    }
}
