//
//  BeamTextEdit+Gutter.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation

extension BeamTextEdit {

    func addGutterItem(item: GutterItem, toLeadingGutter: Bool) {
        if toLeadingGutter {
            guard let gutter = leadingGutter else { return }
            gutter.addItem(item)
        } else {
            guard let gutter = trailingGutter else { return }
            gutter.addItem(item)
        }
    }

    func removeGutterItem(item: GutterItem, fromLeadingGutter: Bool) {
        if fromLeadingGutter {
            guard let gutter = leadingGutter else { return }
            gutter.removeItem(item)
        } else {
            guard let gutter = trailingGutter else { return }
            gutter.removeItem(item)
        }
    }

    private var leadingGutter: GutterContainerView? {
        var gutter = subviews.first { $0 is GutterContainerView && ($0 as? GutterContainerView)?.isLeading == true} as? GutterContainerView
        if gutter == nil {
            gutter = setupLeadingGutter()
        }
        return gutter
    }

    private func setupLeadingGutter() -> GutterContainerView? {
        guard let calendarManager = state?.data.calendarManager, !calendarManager.connectedSources.isEmpty else { return nil }
        let viewModel = CalendarGutterViewModel(calendarManager: calendarManager, noteId: self.note.id)
        let gutter = GutterContainerView(frame: NSRect.zero, isLeading: true, leadingGutterViewType: LeadingGutterView.LeadingGutterViewType.calendarGutterView(viewModel: viewModel))
        DispatchQueue.main.async {
            self.addSubview(gutter, positioned: .above, relativeTo: nil)
        }
        return gutter
    }

    func updateLeadingGutterLayout(textRect: NSRect) {
        let containerSize = frame.size
        var gutterFrame = CGRect.zero
        gutterFrame.origin = CGPoint(x: 0, y: textRect.minY)
        gutterFrame.size = CGSize(width: gutterFrame.minX + textRect.minX, height: containerSize.height - gutterFrame.minY)
        DispatchQueue.main.async { [weak self] in
            self?.leadingGutter?.frame = gutterFrame
        }
    }

    func updateCalendarLeadingGutter(for noteId: UUID) {
        guard let calendarManager = state?.data.calendarManager, !calendarManager.connectedSources.isEmpty else { return }
        let viewModel = CalendarGutterViewModel(calendarManager: calendarManager, noteId: noteId)
        self.leadingGutter?.leadingGutterViewType = LeadingGutterView.LeadingGutterViewType.calendarGutterView(viewModel: viewModel)
    }

    private var trailingGutter: GutterContainerView? {
        var gutter = subviews.first { $0 is GutterContainerView && ($0 as? GutterContainerView)?.isLeading == false} as? GutterContainerView
        if gutter == nil {
            gutter = setupTrailingGutter()
        }
        return gutter
    }

    private func setupTrailingGutter() -> GutterContainerView {
        let gutter = GutterContainerView(frame: NSRect.zero, isLeading: false)
        DispatchQueue.main.async {
            self.addSubview(gutter, positioned: .above, relativeTo: nil)
        }
        return gutter
    }

    func updateTrailingGutterLayout(textRect: NSRect) {
        let containerSize = frame.size
        var gutterFrame = CGRect.zero
        gutterFrame.origin = CGPoint(x: textRect.maxX, y: 0)
        gutterFrame.size = CGSize(width: containerSize.width - gutterFrame.minX, height: containerSize.height - gutterFrame.minY)
        DispatchQueue.main.async { [weak self] in
            self?.trailingGutter?.frame = gutterFrame
        }
    }
}
