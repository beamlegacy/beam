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
    var contentLeadingInset: CGFloat = 8
    var isHovering = false

    private var textSize: CGSize?

    var shouldDrawSortIndicator: (ascending: Bool, priority: Int)?

    override func drawSortIndicator(withFrame cellFrame: NSRect, in controlView: NSView, ascending: Bool, priority: Int) {
        shouldDrawSortIndicator = (ascending, priority)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var interiorFrame = cellFrame
        interiorFrame.size.width += 20 // we manually handle the sort indicator, let's give more space to the text then.
        super.drawInterior(withFrame: interiorFrame, in: controlView)
        var textRect = titleRect(forBounds: interiorFrame)
        textRect.size = textSize ?? .zero
        textRect.origin.x += 4
        if let indicator = shouldDrawSortIndicator {
            let imageRect = CGRect(x: textRect.maxX, y: 8, width: 8, height: 8)
            let image = indicator.ascending ? Self.flippedSortedIndicatorImage : Self.sortedIndicatorImage
            image?.fill(color: BeamColor.AlphaGray.nsColor).draw(in: imageRect)
            shouldDrawSortIndicator = nil
        }
    }

    func drawBottomBorder(withFrame cellFrame: NSRect) {
        guard drawsBottomBorder else { return }
        BeamColor.Mercury.nsColor.withAlphaComponent(0.5).setFill()
        let borderRect = CGRect(x: cellFrame.minX, y: cellFrame.maxY - 1, width: cellFrame.width, height: 1)
        let linePath = NSBezierPath(rect: borderRect)
        linePath.fill()
    }

    func drawTrailingBorder(withFrame interiorFrame: NSRect) {
        guard drawsTrailingBorder else { return }
        BeamColor.Mercury.nsColor.withAlphaComponent(0.5).setFill()
        let borderRect = CGRect(x: interiorFrame.maxX - 1, y: interiorFrame.minY, width: 1, height: interiorFrame.height)
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
        var interiorFrame = cellFrame.insetBy(dx: 0, dy: 5)
        interiorFrame.size.height -= 3
        interiorFrame.origin.x += contentLeadingInset
        interiorFrame.size.width -= contentLeadingInset
        drawTrailingBorder(withFrame: interiorFrame)
        drawInterior(withFrame: interiorFrame, in: controlView)
    }
}
