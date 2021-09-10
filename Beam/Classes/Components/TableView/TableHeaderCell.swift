//
//  TableHeaderCell.swift
//  Beam
//
//  Created by Remi Santos on 08/09/2021.
//

import Foundation

class TableHeaderCell: NSTableHeaderCell {

    private static var sortedIndicatorImage: NSImage? = {
        NSImage(named: "editor-breadcrumb_down")
    }()

    private static var flippedSortedIndicatorImage: NSImage? = {
        NSImage(named: "editor-breadcrumb_up")
    }()

    var drawsTrailingBorder = true
    var drawsBottomBorder = true

    private var textSize: CGSize?

    var shouldDrawSortIndicator: (ascending: Bool, priority: Int)?

    override func drawSortIndicator(withFrame cellFrame: NSRect, in controlView: NSView, ascending: Bool, priority: Int) {
        shouldDrawSortIndicator = (ascending, priority)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: cellFrame, in: controlView)
        var textRect = titleRect(forBounds: cellFrame)
        textRect.size = textSize ?? .zero
        textRect.origin.x += 2
        if let indicator = shouldDrawSortIndicator {
            let imageRect = CGRect(x: textRect.maxX, y: 8, width: 8, height: 8)
            let image = indicator.ascending ? Self.flippedSortedIndicatorImage : Self.sortedIndicatorImage
            image?.fill(color: BeamColor.AlphaGray.nsColor).draw(in: imageRect)
            shouldDrawSortIndicator = nil
        }
    }

    func drawBottomBorder(withFrame cellFrame: NSRect) {
        guard drawsBottomBorder else { return }
        BeamColor.Mercury.nsColor.setFill()
        let borderRect = CGRect(x: cellFrame.minX, y: cellFrame.maxY - 1, width: cellFrame.width, height: 1)
        let linePath = NSBezierPath(rect: borderRect)
        linePath.fill()
    }

    func drawTrailingBorder(withFrame cellFrame: NSRect) {
        guard drawsTrailingBorder else { return }
        BeamColor.Mercury.nsColor.setFill()
        let borderRect = CGRect(x: cellFrame.maxX - 1, y: 5, width: 1, height: cellFrame.height - 10)
        let linePath = NSBezierPath(rect: borderRect)
        linePath.fill()
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if textSize == nil {
            let tf = NSTextField(labelWithString: title)
            tf.font = self.font
            textSize = tf.intrinsicContentSize
        }
        BeamColor.Generic.background.nsColor.setFill()
        NSBezierPath(rect: cellFrame).fill()
        drawBottomBorder(withFrame: cellFrame)
        drawTrailingBorder(withFrame: cellFrame)
        var interiorFrame = cellFrame.insetBy(dx: 0, dy: 5)
        interiorFrame.origin.x += 8
        drawInterior(withFrame: interiorFrame, in: controlView)
    }
}
