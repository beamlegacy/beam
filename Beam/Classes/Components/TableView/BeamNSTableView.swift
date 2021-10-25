//
//  BeamNSTableView.swift
//  Beam
//
//  Created by Remi Santos on 13/04/2021.
//

import Foundation

protocol BeamNSTableViewDelegate: AnyObject {
    func tableViewDidChangeEffectiveAppearance(_ tableView: BeamNSTableView)
    func tableView(_ tableView: BeamNSTableView, mouseDownFor row: Int, column: Int, locationInWindow: NSPoint) -> Bool
    func tableView(_ tableView: BeamNSTableView, rightMouseDownFor row: Int, column: Int, locationInWindow: NSPoint)
    func tableView(_ tableView: BeamNSTableView, didDoubleTap row: Int)
}

class BeamNSTableView: NSTableView {

    weak var additionalDelegate: BeamNSTableViewDelegate?

    init() {
        super.init(frame: .zero)
        self.target = self
        self.doubleAction = #selector(didDoubleSelectRow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        additionalDelegate?.tableViewDidChangeEffectiveAppearance(self)
    }

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

    @objc func didDoubleSelectRow() {
        guard let additionalDelegate = additionalDelegate else { return }
        additionalDelegate.tableView(self, didDoubleTap: self.selectedRow)
    }
}
