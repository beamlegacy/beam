//
//  BeamNSTableView.swift
//  Beam
//
//  Created by Remi Santos on 13/04/2021.
//

import Foundation

protocol BeamNSTableViewDelegate: AnyObject {
    func tableView(_ tableView: BeamNSTableView, mouseDownFor row: Int, column: Int, locationInWindow: NSPoint) -> Bool
    func tableView(_ tableView: BeamNSTableView, rightMouseDownFor row: Int, column: Int, locationInWindow: NSPoint)
}

class BeamNSTableView: NSTableView {

    weak var additionalDelegate: BeamNSTableViewDelegate?

    private func rowAndColumngForWindowLocation(_ locationInWindow: NSPoint) -> (Int, Int)? {
        let localLocation = convert(locationInWindow, from: nil)
        let row = self.row(at: localLocation)
        let column = self.column(at: localLocation)
        guard row >= 0 && column >= 0 else { return nil }
        return (row, column)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        guard let additionalDelegate = additionalDelegate,
              let (row, column) = rowAndColumngForWindowLocation(event.locationInWindow)
        else { return }
        additionalDelegate.tableView(self, rightMouseDownFor: row, column: column, locationInWindow: event.locationInWindow)
    }

    override func mouseDown(with event: NSEvent) {
        var shouldPropagate = true
        if let additionalDelegate = additionalDelegate,
              let (row, column) = rowAndColumngForWindowLocation(event.locationInWindow) {
            shouldPropagate = additionalDelegate.tableView(self, mouseDownFor: row, column: column, locationInWindow: event.locationInWindow)
        }
        guard shouldPropagate else { return }
        super.mouseDown(with: event)
    }
}
