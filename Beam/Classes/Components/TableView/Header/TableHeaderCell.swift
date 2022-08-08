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
    private var headerTitleColor: NSColor
    private var headerBackgroundColor: NSColor

    var shouldDrawSortIndicator: (ascending: Bool, priority: Int)?

    // Had to go with this trick thanks to Thomas.
    // Since NSTableHeaderCell are copied but doesn't strongly retain we need to do this to avoid a crash when being deallocated
    override func copy(with zone: NSZone? = nil) -> Any {
        let cell = super.copy(with: zone) as! TableHeaderCell

        _ = Unmanaged.passRetained(cell.headerTitleColor)
        _ = Unmanaged.passRetained(cell.headerBackgroundColor)

        return cell
    }

    init(textCell: String, headerTitleColor: NSColor = BeamColor.AlphaGray.nsColor, headerBackgroundColor: NSColor = BeamColor.Generic.background.nsColor) {
        self.headerTitleColor = headerTitleColor
        self.headerBackgroundColor = headerBackgroundColor

        super.init(textCell: textCell)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        textColor = headerTitleColor
        if let indicator = shouldDrawSortIndicator {
            let imageRect = CGRect(x: textRect.maxX, y: 9, width: 8, height: 8)
            let image = indicator.ascending ? Self.flippedSortedIndicatorImage : Self.sortedIndicatorImage
            image?.fill(color: headerTitleColor).draw(in: imageRect)
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
        headerBackgroundColor.setFill()
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
