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

    private var axes: Axis.Set
    private var showsIndicators: Bool

    let data: BeamData
    let dataSource: [BeamNote]
    let proxy: GeometryProxy
    @State var fetchedEntries: [BeamNote] = []
    @State private var isEditing = false
    @EnvironmentObject var state: BeamState

    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, data: BeamData, dataSource: [BeamNote], proxy: GeometryProxy) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.data = data
        self.dataSource = dataSource
        self.proxy = proxy
    }

    public func makeCoordinator() -> JournalScrollViewCoordinator {
        return JournalScrollViewCoordinator(scrollView: self, data: self.data, dataSource: self.dataSource, fetchedEntries: $fetchedEntries)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = axes.contains(.vertical)
        scrollView.hasHorizontalScroller = axes.contains(.horizontal)
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.horizontalScroller?.alphaValue = 0
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.editorBackgroundColor

        // Initial document view
        let journalStackView = JournalStackView(horizontalSpace: 40, topOffset: self.proxy.size.height * 0.2)
        journalStackView.frame = NSRect(x: 0, y: 0, width: proxy.size.width, height: proxy.size.height)
        scrollView.documentView = journalStackView

        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .top, relatedBy: .equal, toItem: scrollView.contentView, attribute: .top, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .leading, relatedBy: .equal, toItem: scrollView.contentView, attribute: .leading, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .trailing, relatedBy: .equal, toItem: scrollView.contentView, attribute: .trailing, multiplier: 1.0, constant: 0))

        for note in dataSource {
            let textEditView = getTextEditView(for: note)
            journalStackView.addChildView(view: textEditView)
        }

        context.coordinator.watchScrollViewBounds(scrollView)
        return scrollView

    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let journalStackView = nsView.documentView as? JournalStackView else { return }
        journalStackView.invalidateLayout()
        if !fetchedEntries.isEmpty {
            for note in fetchedEntries {
                let textEditView = getTextEditView(for: note)
                journalStackView.addChildView(view: textEditView)
            }
            DispatchQueue.main.async {
                fetchedEntries = []
            }
        }
        journalStackView.layout()
    }

    private func getTextEditView(for note: BeamNote) -> BeamTextEdit {
        let textEditView = BeamTextEdit(root: note, journalMode: true)
        textEditView.data = data
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
        textEditView.openCard = { cardName in
            self.state.navigateToNote(named: cardName)
        }
        textEditView.onStartQuery = { textNode in
            self.state.startQuery(textNode)
        }
        textEditView.minimumWidth = 800
        textEditView.maximumWidth = 1024
        textEditView.footerHeight = 0
        textEditView.topOffset = 0
        textEditView.leadingAlignment = 160
        textEditView.traillingPadding = 80
        textEditView.centerText = true
        textEditView.showTitle = false

        return textEditView
    }

    public class JournalScrollViewCoordinator: NSObject {
        let parent: JournalScrollView
        internal var scrollViewContentWatcher: ScrollViewContentWatcher?

        private let data: BeamData
        private let dataSource: [BeamNote]
        @Binding var fetchedEntries: [BeamNote]

        public init(scrollView: JournalScrollView, data: BeamData, dataSource: [BeamNote], fetchedEntries: Binding<[BeamNote]>) {
            self.parent = scrollView
            self.data = data
            self.dataSource = dataSource
            self._fetchedEntries = fetchedEntries
        }

        func watchScrollViewBounds(_ scrollView: NSScrollView) {
            scrollViewContentWatcher = ScrollViewContentWatcher(with: scrollView, data: data, dataSource: dataSource, fetchedEntries: $fetchedEntries)
        }
    }
}

class ScrollViewContentWatcher: NSObject {
    private var bounds: NSRect = .zero
    private let data: BeamData
    private var dataSource: [BeamNote]
    @Binding var fetchedEntries: [BeamNote]

    init(with scrollView: NSScrollView, data: BeamData, dataSource: [BeamNote], fetchedEntries: Binding<[BeamNote]>) {
        self.data = data
        self.dataSource = dataSource
        self._fetchedEntries = fetchedEntries

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
        let maxContentOffSetY = documentView.bounds.height - clipView.bounds.height
        bounds = clipView.bounds
        // Update position of todays item
        if let todaysNote = documentView.getTodaysView() {
            let newPosition = bounds.origin.y + documentView.topOffset
            todaysNote.frame.origin.y = max(documentView.topOffset, min(newPosition, documentView.todaysMaxPosition))
        }
        // Update visibility and position of side title layer
        documentView.updateSideLayer(scrollValue: diff, scrollingDown: scrollingDown, y: bounds.origin.y)

        // Update DataSource when scrollview is close to the end
        if maxContentOffSetY - bounds.origin.y <= 5 {
            loadMore()
        }
    }

    private func loadMore() {
        let totalJournal = data.documentManager.countDocumentsWithType(type: .journal)
        if totalJournal != self.dataSource.count {
            data.updateJournal(with: 2, and: dataSource.count)
            fetchedEntries = data.journal.filter({ !dataSource.contains($0) })
            dataSource = data.journal
        }
        // Imo we shouldn't have a case were totalJournal == 0, but alway >= 1
        data.isFetching = totalJournal != data.journal.count && totalJournal != 0
    }
}
