//
//  BeamNSTableView.swift
//  Beam
//
//  Created by Remi Santos on 13/04/2021.
//

import Foundation

protocol BeamNSTableViewDelegate: class {
    func tableView(_ tableView: BeamNSTableView, mouseDownFor row: Int, column: Int, locationInWindow: NSPoint)
    func tableView(_ tableView: BeamNSTableView, rightMouseDownFor row: Int, column: Int, locationInWindow: NSPoint)
}

class BeamNSTableView: NSTableView {

    weak var additionalDelegate: BeamNSTableViewDelegate?

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)

        if let additionalDelegate = additionalDelegate {
            let localLocation = convert(event.locationInWindow, from: nil)
            let row = self.row(at: localLocation)
            let column = self.column(at: localLocation)
            additionalDelegate.tableView(self, rightMouseDownFor: row, column: column, locationInWindow: event.locationInWindow)
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let additionalDelegate = additionalDelegate {
            let localLocation = convert(event.locationInWindow, from: nil)
            let row = self.row(at: localLocation)
            let column = self.column(at: localLocation)
            additionalDelegate.tableView(self, mouseDownFor: row, column: column, locationInWindow: event.locationInWindow)
        }
    }
}
