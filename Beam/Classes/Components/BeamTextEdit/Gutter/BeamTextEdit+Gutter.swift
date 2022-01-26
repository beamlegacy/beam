//
//  BeamTextEdit+Gutter.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation

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
            viewModel.$meetings.dropFirst().sink { meetings in
                if viewModel.meetings.count != meetings.count {
                    self.superview?.invalidateIntrinsicContentSize()
                }
            }.store(in: &scope)
        case .none: break
        }
    }

    func updateCalendarLeadingGutter(for noteId: UUID) {
        guard let calendarManager = state?.data.calendarManager, !calendarManager.connectedSources.isEmpty else { return }
        let viewModel = CalendarGutterViewModel(root: self.rootNode, calendarManager: calendarManager, noteId: noteId, todaysCalendar: state?.data.todaysNote.id == noteId)
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
