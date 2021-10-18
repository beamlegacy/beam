import Foundation

extension NSTableView {
    func scrollRowToVisible(_ row: Int, animated: Bool, flash: Bool = false) {
        if animated {
            let rowRect = self.rect(ofRow: row)
            var scrollOrigin = rowRect.origin
            guard let clipView = self.superview as? NSClipView else { return }

            let tableHalfHeight = NSHeight(clipView.frame)*0.5
            let rowRectHalfHeight = NSHeight(rowRect)*0.5

            scrollOrigin.y = (scrollOrigin.y - tableHalfHeight) + rowRectHalfHeight

            if flash {
                clipView.enclosingScrollView?.flashScrollers()
            }

            clipView.animator().setBoundsOrigin(scrollOrigin)
        } else {
            self.scrollRowToVisible(row)
        }
    }
}
