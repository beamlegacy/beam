//
//  WKWindowFeatures+Beam.swift
//  Beam
//
//  Created by Stef Kors on 24/02/2022.
//

import Foundation

extension WKWindowFeatures {
    /// Returns CGRect for x, y, width and height window feature values.
    /// Values that aren't available will default to `.zero`
    /// - Returns: Rect
    func toRect() -> NSRect {
        let x: CGFloat = self.x?.doubleValue ?? .zero
        let y: CGFloat = self.y?.doubleValue ?? .zero
        let width: CGFloat = self.width?.doubleValue ?? .zero
        let height: CGFloat = self.height?.doubleValue ?? .zero
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

class BeamWindowFeatures: WKWindowFeatures {
    override var allowsResizing: NSNumber? { 1 }
    override var statusBarVisibility: NSNumber? { 1 }
    override var menuBarVisibility: NSNumber? { 1 }
    override var toolbarsVisibility: NSNumber? { 1 }

    var origin: CGPoint?
}
