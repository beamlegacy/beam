//
//  TableHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 16/09/2021.
//

import Foundation

class TableHeaderView: NSTableHeaderView {

    var onHoverColumn: ((_ colum: Int, _ hovering: Bool) -> Void)?

    private var previousHoveredColumn: Int?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self, userInfo: nil
        )
        self.addTrackingArea(newArea)
    }

    private func columnAtEvent(_ event: NSEvent) -> Int? {
        let localLocation = convert(event.locationInWindow, from: nil)
        let column = self.column(at: localLocation)
        return column >= 0 ? column : nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let column = columnAtEvent(event) else { return }
        onHoverColumn?(column, true)
        previousHoveredColumn = column
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let column = columnAtEvent(event)
        guard column != previousHoveredColumn else { return }
        if let previousHoveredColumn = previousHoveredColumn {
            onHoverColumn?(previousHoveredColumn, false)
        }
        previousHoveredColumn = column
        if let column = column {
            onHoverColumn?(column, true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let previousHoveredColumn = previousHoveredColumn {
            onHoverColumn?(previousHoveredColumn, false)
        }
    }
}
