//
//  BTextEdit.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import SwiftUI
import AppKit
import Combine
import BeamCore

public struct BTextEditScrollable: NSViewRepresentable {
    public typealias NSViewType = NSScrollView

    var note: BeamNote
    var data: BeamData
    var openURL: (URL, BeamElement) -> Void
    var openCard: (UUID, UUID?) -> Void
    var startQuery: (TextNode, Bool) -> Void = { _, _ in }

    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onFocusChanged: ((UUID, Int) -> Void)?
    var onScroll: ((CGPoint) -> Void)?

    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024
    var topOffset = CGFloat(28)
    var footerHeight = CGFloat(28)
    var leadingPercentage = PreferencesManager.editorLeadingPercentage
    var centerText = PreferencesManager.editorIsCentered
    var showTitle = true
    var initialFocusedState: NoteEditFocusedState?

    var headerView: AnyView?

    private let focusOnAppear = true

    public func makeCoordinator() -> BTextEditScrollableCoordinator {
        BTextEditScrollableCoordinator(self)
    }

    public func makeNSView(context: Context) -> NSViewType {
        let edit = BeamTextEdit(root: note, journalMode: false)

        edit.data = data
        updateEditorProperties(edit, context: context)

        let scrollView = buildScrollView()
        edit.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = edit
        scrollView.contentView.addConstraints([
            scrollView.contentView.leftAnchor.constraint(equalTo: edit.leftAnchor),
            scrollView.contentView.rightAnchor.constraint(equalTo: edit.rightAnchor),
            scrollView.contentView.topAnchor.constraint(equalTo: edit.topAnchor)
        ])

        context.coordinator.adjustScrollViewContentAutomatically(scrollView)
        updateHeaderView(scrollView, context: context)
        if focusOnAppear {
            focusEditor(edit)
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let edit = nsView.documentView as? BeamTextEdit else { return }

        updateEditorProperties(edit, context: context)
        if edit.note !== note {
            edit.note = note
            if focusOnAppear {
                focusEditor(edit)
            }
        }

        updateHeaderView(nsView, context: context)
        context.coordinator.onDeinit = { [weak edit] in
            edit?.hideFloatingView()
        }
    }

    private func updateEditorProperties(_ editor: BeamTextEdit, context: Context) {
        editor.openURL = openURL
        editor.openCard = openCard
        editor.startQuery = startQuery

        editor.onStartEditing = onStartEditing
        editor.onEndEditing = onEndEditing
        editor.onFocusChanged = onFocusChanged

        editor.minimumWidth = minimumWidth
        editor.maximumWidth = maximumWidth
        editor.topOffset = topOffset
        editor.footerHeight = footerHeight + context.coordinator.compensatingBottomInset
        editor.leadingPercentage = leadingPercentage
        editor.centerText = centerText

        editor.showTitle = showTitle
    }

    private func focusEditor(_ editor: BeamTextEdit) {
        if let fs = initialFocusedState {
            editor.focusElement(withId: fs.elementId, atCursorPosition: fs.cursorPosition, highlight: fs.highlight)
        }
        DispatchQueue.main.async {
            editor.window?.makeFirstResponder(editor)
        }
    }

    private func updateHeaderView(_ scrollView: NSViewType, context: Context) {
        guard let headerView = headerView, let documentView = scrollView.documentView
        else { return }
        context.coordinator.headerHostingView?.removeFromSuperview()
        let hosting = NSHostingView<AnyView>(rootView: headerView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hosting)
        documentView.addConstraints([
            hosting.leftAnchor.constraint(equalTo: documentView.leftAnchor),
            hosting.rightAnchor.constraint(equalTo: documentView.rightAnchor),
            hosting.topAnchor.constraint(equalTo: documentView.topAnchor)
        ])
        context.coordinator.headerHostingView = hosting
    }

    private func buildScrollView() -> NSScrollView {
        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.drawsBackground = false

        let scrollView = NSScrollView()
        scrollView.contentView = clipView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        return scrollView
    }
}

extension BTextEditScrollable {
    public class BTextEditScrollableCoordinator: NSObject, ScrollViewContentAdjusterDelegate {
        private let parent: BTextEditScrollable
        fileprivate var onDeinit: () -> Void = {}
        fileprivate var compensatingBottomInset = CGFloat(0)
        fileprivate var headerHostingView: NSHostingView<AnyView>?

        private var scrollViewContentAdjuster: ScrollViewContentAdjuster?

        init(_ edit: BTextEditScrollable) {
            self.parent = edit
        }

        func adjustScrollViewContentAutomatically(_ scrollView: NSScrollView) {
            scrollViewContentAdjuster = ScrollViewContentAdjuster(with: scrollView)
            scrollViewContentAdjuster?.delegate = self
        }

        deinit {
            onDeinit()
        }

        func scrollViewNeedOffsetCompensation(of: CGSize) {
            compensatingBottomInset = of.height
        }

        func scrollViewDidScroll(to point: CGPoint) {
            parent.onScroll?(point)
        }
    }
}

/**
 A NSScrollView helper that will adjust behavior when resizing the container or content.
 Currently only support content height becoming smaller.
*/
protocol ScrollViewContentAdjusterDelegate: AnyObject {
    func scrollViewDidScroll(to point: CGPoint)
    func scrollViewNeedOffsetCompensation(of: CGSize)
}

@objc class ScrollViewContentAdjuster: NSObject {
    weak var delegate: ScrollViewContentAdjusterDelegate?

    private var lastContentBounds: NSRect = .zero
    private var offsetCompensation: CGSize = .zero {
        didSet {
            delegate?.scrollViewNeedOffsetCompensation(of: offsetCompensation)
        }
    }

    init(with scrollView: NSScrollView) {
        super.init()
        let documentView = scrollView.documentView
        documentView?.postsFrameChangedNotifications = true
        let contentView = scrollView.contentView
        contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: contentView)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentSizeDidChange(notification:)),
                                               name: NSView.frameDidChangeNotification,
                                               object: documentView)
    }

    private func didContentHeightChange(for documentView: NSView) -> Bool {
        let newContentSize = documentView.bounds
        return lastContentBounds.size.height != newContentSize.height
    }

    @objc private func contentOffsetDidChange(notification: Notification) {
        guard let clipView = notification.object as? NSClipView, let scrollView = clipView.superview as? NSScrollView, let documentView = scrollView.documentView else {
            return
        }
        guard !didContentHeightChange(for: documentView) else {
            // content offset changed because content size changed
            // let the didContentSizeChange handler do its job
            return
        }
        lastContentBounds.origin = clipView.bounds.origin
        delegate?.scrollViewDidScroll(to: clipView.bounds.origin)
        if offsetCompensation != .zero && documentView.frame.height - clipView.bounds.origin.y - clipView.bounds.height > offsetCompensation.height {
            // reset compensating height when out of view
            offsetCompensation = .zero
        }
    }

    @objc private func contentSizeDidChange(notification: Notification) {
        guard let documentView = notification.object as? NSView, let clipView = documentView.superview as? NSClipView, let scrollView = clipView.superview as? NSScrollView  else {
            return
        }
        let containerSize = scrollView.bounds.size
        let contentSize = documentView.bounds.size
        let previousContentOffset = lastContentBounds.origin
        let isNewContentShorterThanViewHeight = contentSize.height - previousContentOffset.y < containerSize.height
        let willPreviousOffsetBeOutOfBounds = previousContentOffset.y > contentSize.height - (containerSize.height * 0.5)
        if isNewContentShorterThanViewHeight && !willPreviousOffsetBeOutOfBounds {
            // Force the content offset to stay the same
            // even if that means having a white space at the bottom
            // but no more than 0.5 * the window height
            let height = previousContentOffset.y - scrollView.contentView.bounds.origin.y
            offsetCompensation = CGSize(width: 0, height: height)
            scrollView.scroll(scrollView.contentView, to: previousContentOffset)
        } else {
            lastContentBounds.origin = scrollView.contentView.bounds.origin
        }
        lastContentBounds.size = contentSize
    }
}
