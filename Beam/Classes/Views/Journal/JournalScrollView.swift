//
//  JournalScrollView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/03/2021.
//

import Foundation
import SwiftUI
import BeamCore

struct JournalScrollView: NSViewRepresentable {
    typealias NSViewType = NSScrollView

    var axes: Axis.Set
    var showsIndicators: Bool
    var centerText: Bool
    let proxy: GeometryProxy
    let onScroll: ((CGPoint) -> Void)?

    @State private var isEditing = false
    @EnvironmentObject var state: BeamState

    public func makeCoordinator() -> JournalScrollViewCoordinator {
        return JournalScrollViewCoordinator(scrollView: self, data: state.data, dataSource: state.data.journal)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.hasVerticalScroller = axes.contains(.vertical)
        scrollView.hasHorizontalScroller = axes.contains(.horizontal)
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.horizontalScroller?.alphaValue = 0
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = BeamColor.Generic.background.nsColor

        // Initial document view
        let journalStackView = JournalStackView(horizontalSpace: 0,
                                                topOffset: Self.firstNoteTopOffset(forProxy: proxy))
        journalStackView.frame = NSRect(x: 0, y: 0, width: proxy.size.width, height: proxy.size.height)
        scrollView.documentView = journalStackView

        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .top, relatedBy: .equal, toItem: scrollView.contentView, attribute: .top, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .leading, relatedBy: .equal, toItem: scrollView.contentView, attribute: .leading, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .trailing, relatedBy: .equal, toItem: scrollView.contentView, attribute: .trailing, multiplier: 1.0, constant: 0))

        set(data: state.data.journal, in: journalStackView)

        context.coordinator.watchScrollViewBounds(scrollView)
        return scrollView

    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let journalStackView = nsView.documentView as? JournalStackView else { return }
        journalStackView.invalidateLayout()
        if state.data.newDay {
            journalStackView.removeChildViews()
            state.data.reloadJournal()
        }
        set(data: state.data.journal, in: journalStackView)

        journalStackView.layout()
    }

    private func set(data: [BeamNote], in journalStackView: JournalStackView) {
        if data.isEmpty {
            journalStackView.removeChildViews()
            return
        }
        for note in data {
            guard !journalStackView.hasChildViews(for: note) else { continue }
            if !note.isEntireNoteEmpty() || note.isTodaysNote {
                let textEditView = getTextEditView(for: note)
                journalStackView.addChildView(view: textEditView)
            }
        }
    }

    private func getTextEditView(for note: BeamNote) -> BeamTextEdit {
        let textEditView = BeamTextEdit(root: note, journalMode: true)
        textEditView.data = state.data
        textEditView.onStartEditing = {
            self.isEditing = true
        }
        textEditView.openURL = { url, element in
            if URL.urlSchemes.contains(url.scheme) {
                self.state.createTabFromNote(note, element: element, withURL: url)
            } else {
                if let noteTitle = url.absoluteString.removingPercentEncoding {
                    self.state.navigateToNote(named: noteTitle)
                }
            }
        }
        textEditView.openCard = { cardId, elementId in
            self.state.navigateToNote(id: cardId, elementId: elementId)
        }
        textEditView.startQuery = { textNode, animated in
            self.state.startQuery(textNode, animated: animated)
        }
        textEditView.onFocusChanged = { elementId, cursorPosition in
            self.state.updateNoteFocusedState(note: note, focusedElement: elementId, cursorPosition: cursorPosition)
        }
        textEditView.minimumWidth = 800
        textEditView.maximumWidth = 1024
        textEditView.footerHeight = 0
        textEditView.topOffset = 0
        textEditView.leadingPercentage = 48.7
        textEditView.centerText = centerText
        textEditView.showTitle = true

        return textEditView
    }

    public class JournalScrollViewCoordinator: NSObject {
        let parent: JournalScrollView
        internal var scrollViewContentWatcher: ScrollViewContentWatcher?

        private let data: BeamData
        private let dataSource: [BeamNote]

        public init(scrollView: JournalScrollView, data: BeamData, dataSource: [BeamNote]) {
            self.parent = scrollView
            self.data = data
            self.dataSource = dataSource
        }

        func watchScrollViewBounds(_ scrollView: NSScrollView) {
            scrollViewContentWatcher = ScrollViewContentWatcher(with: scrollView, data: data, dataSource: dataSource)
            scrollViewContentWatcher?.onScroll = parent.onScroll
        }
    }
}

extension JournalScrollView {
    static func firstNoteTopOffset(forProxy proxy: GeometryProxy) -> CGFloat {
        return proxy.size.height * 0.2
    }
}

class ScrollViewContentWatcher: NSObject {
    private var bounds: NSRect = .zero
    private let data: BeamData
    private var dataSource: [BeamNote]
    var onScroll: ((CGPoint) -> Void)?

    init(with scrollView: NSScrollView, data: BeamData, dataSource: [BeamNote]) {
        self.data = data
        self.dataSource = dataSource

        super.init()
        let contentView = scrollView.contentView
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: contentView)
    }

    @objc private func contentOffsetDidChange(notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              let scrollView = clipView.superview as? NSScrollView,
              let documentView = scrollView.documentView as? JournalStackView else { return }
        let scrollingDown = clipView.bounds.origin.y > bounds.origin.y
        let diff = clipView.bounds.origin.y - bounds.origin.y
        var maxContentOffSetY = documentView.bounds.height - clipView.bounds.height - documentView.topOffset
        maxContentOffSetY = documentView.bottomInsetForToday > 0 ? maxContentOffSetY - documentView.bottomInsetForToday : maxContentOffSetY
        bounds = clipView.bounds
        // Update position of todays item
        if let todaysNote = documentView.getTodaysView() {
            let newPosition = bounds.origin.y + documentView.topOffset
            todaysNote.frame.origin.y = max(documentView.topOffset, min(newPosition, documentView.todaysMaxPosition))
        }
        // Update visibility and position of side title layer
        documentView.updateSideLayer(scrollValue: diff, scrollingDown: scrollingDown, y: bounds.origin.y)

        // Update DataSource when scrollview is close to the end
        if maxContentOffSetY - bounds.origin.y <= 10 {
            loadMore()
        }
        onScroll?(clipView.bounds.origin)
    }

    private func loadMore() {
        let totalJournal = data.documentManager.countDocumentsWithType(type: .journal)
        if totalJournal != self.dataSource.count {
            data.updateJournal(with: 2, and: dataSource.count)
            dataSource = data.journal
        }
        // Imo we shouldn't have a case were totalJournal == 0, but alway >= 1
        data.isFetching = totalJournal != data.journal.count && totalJournal != 0
    }
}
