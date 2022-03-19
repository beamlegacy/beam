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
    typealias StackView = JournalSimpleStackView

    var USE_SCROLLVIEW_CACHING = false
    var USE_STACKVIEW_CACHING = PreferencesManager.createJournalOncePerWindow

    var axes: Axis.Set
    var showsIndicators: Bool
    var topInset: CGFloat = 0
    let proxy: GeometryProxy
    let onScroll: ((CGPoint) -> Void)?
    let onEndLiveScroll: ((CGPoint) -> Void)?

    @State private var isEditing = false
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var data: BeamData

    public func makeCoordinator() -> JournalScrollViewCoordinator {
        return JournalScrollViewCoordinator(scrollView: self, data: state.data)
    }

    func createStackView() -> StackView {
        if USE_STACKVIEW_CACHING, let stackView = state.cachedJournalStackView {
            return stackView
        }
        let journalStackView = JournalSimpleStackView(
            state: state,
            safeTop: Toolbar.height,
            onStartEditing: { self.isEditing = true },
            verticalSpace: 0,
            topOffset: Self.firstNoteTopOffset(forProxy: proxy)
        )
        journalStackView.frame = NSRect(x: 0, y: 0, width: proxy.size.width, height: proxy.size.height)
        if USE_STACKVIEW_CACHING {
            state.cachedJournalStackView = journalStackView
        }
        return journalStackView
    }

    func createScrollAndStackViews() -> NSScrollView {
        if USE_SCROLLVIEW_CACHING, let scrollView = state.cachedJournalScrollView {
            return scrollView
        }
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
        if topInset != 0 {
            scrollView.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        }
        // Initial document view
        let journalStackView = createStackView()

        scrollView.documentView = journalStackView

        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .top, relatedBy: .equal, toItem: scrollView.contentView, attribute: .top, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .leading, relatedBy: .equal, toItem: scrollView.contentView, attribute: .leading, multiplier: 1.0, constant: 0))
        scrollView.contentView.addConstraint(NSLayoutConstraint(item: journalStackView, attribute: .trailing, relatedBy: .equal, toItem: scrollView.contentView, attribute: .trailing, multiplier: 1.0, constant: 0))

        journalStackView.setNotes(state.data.journal, focussingOn: state.journalNoteToFocus, force: false)
        resetJournalFocus()
        if USE_SCROLLVIEW_CACHING {
            state.cachedJournalScrollView = scrollView
        }
        journalStackView.scrollToTop(animated: false)
        return scrollView
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = createScrollAndStackViews()
        context.coordinator.watchScrollViewBounds(scrollView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let journalStackView = nsView.documentView as? StackView else { return }
        journalStackView.invalidateLayout()
        if state.data.newDay {
            state.data.reloadJournal()
        }
        journalStackView.topOffset = Self.firstNoteTopOffset(forProxy: proxy)
        journalStackView.setNotes(state.data.journal, focussingOn: state.journalNoteToFocus, force: false)
        resetJournalFocus()
    }

    private func resetJournalFocus() {
        if state.journalNoteToFocus != nil {
            DispatchQueue.main.async {
                state.journalNoteToFocus = nil
            }
        }
    }

    public class JournalScrollViewCoordinator: NSObject {
        let parent: JournalScrollView
        internal var scrollViewContentWatcher: ScrollViewContentWatcher?

        private let data: BeamData

        public init(scrollView: JournalScrollView, data: BeamData) {
            self.parent = scrollView
            self.data = data
        }

        func watchScrollViewBounds(_ scrollView: NSScrollView) {
            scrollViewContentWatcher = ScrollViewContentWatcher(state: parent.state, scrollView: scrollView, data: data)
            scrollViewContentWatcher?.onScroll = parent.onScroll
            scrollViewContentWatcher?.onEndLiveScroll = parent.onEndLiveScroll
        }
    }
}

extension JournalScrollView {
    static func firstNoteTopOffset(forProxy proxy: GeometryProxy) -> CGFloat {
        return OmniboxContainer.firstNoteTopOffsetForJournal(height: proxy.size.height).rounded()
    }
}

class ScrollViewContentWatcher: NSObject {
    private var bounds: NSRect = .zero
    private let data: BeamData
    var onScroll: ((CGPoint) -> Void)?
    var onEndLiveScroll: ((CGPoint) -> Void)?
    weak var contentView: NSClipView?
    weak var state: BeamState?

    init(state: BeamState, scrollView: NSScrollView, data: BeamData) {
        self.data = data
        self.state = state

        super.init()
        contentView = scrollView.contentView
        contentView?.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: contentView)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEndLiveScroll(notification:)),
                                               name: NSScrollView.didEndLiveScrollNotification,
                                               object: scrollView)
    }

    let spaceBeforeLoadingMoreData = CGFloat(2.0)

    @objc private func contentOffsetDidChange(notification: Notification) {
        guard let clipView = notification.object as? NSClipView,
              let scrollView = clipView.superview as? NSScrollView,
              let documentView = scrollView.documentView as? JournalScrollView.StackView else { return }

        bounds = clipView.bounds
        // Update position of todays item
        documentView.updateScrollingFrames()

        // Update journal when scrollview is close to the end
        let offset = bounds.minY
        if offset > documentView.frame.maxY - spaceBeforeLoadingMoreData * bounds.height {
            DispatchQueue.main.async { [weak self] in
                self?.loadMore()
            }
        }
        onScroll?(clipView.bounds.origin)
        state?.lastScrollOffset[UUID.null] = clipView.bounds.origin.y
    }

    @objc private func didEndLiveScroll(notification: Notification) {
        guard let scrollView = notification.object as? NSScrollView else { return }
        onEndLiveScroll?(scrollView.contentView.bounds.origin)
    }

    private func loadMore() {
        data.loadMorePastJournalNotes(count: 1, fetchEvents: true)
    }
}
