//
//  BeamTextEdit+Gutter.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation

extension BeamTextEdit {

    private var trailingGutter: GutterContainerView? {
        var gutter = subviews.first { $0 is GutterContainerView } as? GutterContainerView
        if gutter == nil {
            gutter = setupTrailingGutter()
        }
        return gutter
    }

    func addGutterItem(item: GutterItem) {
        guard let gutter = trailingGutter else { return }
        gutter.addItem(item)
    }

    func removeGutterItem(item: GutterItem) {
        guard let gutter = trailingGutter else { return }
        gutter.removeItem(item)
    }

    private func setupTrailingGutter() -> GutterContainerView {
        let gutter = GutterContainerView()
        self.addSubview(gutter, positioned: .above, relativeTo: nil)
        return gutter
    }

    func updateTrailingGutterLayout(textRect: NSRect) {
        let containerSize = frame.size
        var gutterFrame = CGRect.zero
        gutterFrame.origin = CGPoint(x: textRect.maxX, y: 0)
        gutterFrame.size = CGSize(width: containerSize.width - gutterFrame.minX, height: containerSize.height - gutterFrame.minY)
        trailingGutter?.frame = gutterFrame
    }
}
