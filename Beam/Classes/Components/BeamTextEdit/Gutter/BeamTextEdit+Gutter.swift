//
//  BeamTextEdit+Gutter.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    func addGutterItem(item: GutterItem, toLeadingGutter: Bool) {
        DispatchQueue.main.async { [weak self] in
            if let gutter = self?.leadingGutter, toLeadingGutter {
                gutter.addItem(item)
            } else if let gutter = self?.trailingGutter, !toLeadingGutter {
                gutter.addItem(item)
            }
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
        let isLeadingGutter: (NSView) -> Bool = { view in
            guard let gutterContainerView = view as? GutterContainerView else { return false }
            return gutterContainerView.isLeading
        }

        return subviews.first(where: isLeadingGutter) as? GutterContainerView
    }

    var leadingGutterSize: NSSize {
        guard let gutter = leadingGutter else { return .zero }
        return gutter.intrinsicContentSize
    }

    func setupLeadingGutter(textRect: NSRect) {
        guard let calendarManager = data?.calendarManager, leadingGutter == nil else { return }
        let viewModel = CalendarGutterViewModel(root: self.rootNode, calendarManager: calendarManager, noteId: self.note.id, todaysCalendar: state?.data.todaysNote.id == self.note.id)
        let gutter = GutterContainerView(frame: .zero, isLeading: true, leadingGutterViewType: LeadingGutterView.LeadingGutterViewType.calendarGutterView(viewModel: viewModel))
        gutter.frame.origin = CGPoint(x: 0, y: textRect.minY)
        gutter.frame.size = CGSize(width: textRect.minX, height: gutter.intrinsicContentSize.height)
        self.addSubview(gutter, positioned: .above, relativeTo: nil)
        observeLeading(gutter: gutter)
    }

    private func observeLeading(gutter: GutterContainerView) {
        switch gutter.leadingGutterViewType {
        case .calendarGutterView(let viewModel):
            viewModel.$meetings.dropFirst().sink { [weak self] _ in
                guard let self = self else { return }
                self.updateLeadingGutterLayout(textRect: self.nodesRect)
                self.superview?.invalidateIntrinsicContentSize()
            }.store(in: &scope)
        case .none: break
        }
    }

    func updateLeadingGutterLayout(textRect: NSRect) {
        guard leadingGutter?.frame.height != leadingGutterSize.height ||
                leadingGutter?.frame.width != textRect.minX else { return }
        let fr = CGRect(origin: CGPoint(x: 0, y: textRect.minY), size: CGSize(width: textRect.minX, height: leadingGutterSize.height))
        DispatchQueue.main.async { [weak self] in
            self?.leadingGutter?.frame = fr
        }
    }

    func updateCalendarLeadingGutter(for note: BeamElement) {
        guard let isJournal = note.note?.type.isJournal, isJournal else {
            self.leadingGutter?.removeFromSuperview()
            return
        }
        guard let calendarManager = state?.data.calendarManager else { return }
        let viewModel = CalendarGutterViewModel(root: self.rootNode, calendarManager: calendarManager, noteId: note.id, todaysCalendar: state?.data.todaysNote.id == note.id)
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
        self.addSubview(gutter, positioned: .above, relativeTo: nil)
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
