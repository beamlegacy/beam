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

public struct BTextEdit: NSViewRepresentable {
    var note: BeamNote
    var data: BeamData
    var openURL: (URL, BeamElement) -> Void
    var openCard: (UUID, UUID?) -> Void
    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onStartQuery: (TextNode, Bool) -> Void = { _, _ in }
    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024

    var topOffset: CGFloat = 45
    var footerHeight: CGFloat = 0

    var centerText = false
    var showTitle = true

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> BeamTextEdit {
        let nsView = BeamTextEdit(root: note, journalMode: true)

        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing
        nsView.onStartQuery = onStartQuery

        nsView.minimumWidth = minimumWidth
        nsView.maximumWidth = maximumWidth

        nsView.topOffset = topOffset
        nsView.footerHeight = footerHeight

        nsView.centerText = centerText
        nsView.showTitle = showTitle

        return nsView
    }

    public func updateNSView(_ nsView: BeamTextEdit, context: Context) {
        if nsView.note !== note {
            nsView.note = note
        }

        nsView.data = data
        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing
        nsView.onStartQuery = onStartQuery

        nsView.minimumWidth = minimumWidth
        nsView.maximumWidth = maximumWidth

        nsView.topOffset = topOffset
        nsView.footerHeight = footerHeight

        nsView.centerText = centerText
        nsView.showTitle = showTitle

        context.coordinator.onDeinit = {
            nsView.hideFloatingView()
        }
    }

    public class Coordinator: NSObject {
        let parent: BTextEdit
        var onDeinit: () -> Void = {}

        init(_ edit: BTextEdit) {
            self.parent = edit
        }

        deinit {
            onDeinit()
        }
    }

    public typealias NSViewType = BeamTextEdit
}

public struct BTextEditScrollable: NSViewRepresentable {
    var note: BeamNote
    var data: BeamData
    var openURL: (URL, BeamElement) -> Void
    var openCard: (UUID, UUID?) -> Void
    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onStartQuery: (TextNode, Bool) -> Void = { _, _ in }
    var onScroll: ((CGPoint) -> Void)?
    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024

    var topOffset = CGFloat(28)
    var footerHeight = CGFloat(28)
    var leadingPercentage = CGFloat(48.7)
    var centerText = false
    var showTitle = true

    var scrollToElementId: UUID?
    private let focusOnAppear = true

    public func makeCoordinator() -> BTextEditScrollableCoordinator {
        BTextEditScrollableCoordinator(self)
    }

    public func makeNSView(context: Context) -> NSViewType {
        let edit = BeamTextEdit(root: note, journalMode: false)

        edit.data = data
        edit.openURL = openURL
        edit.openCard = openCard
        edit.onStartEditing = onStartEditing
        edit.onEndEditing = onEndEditing
        edit.onStartQuery = onStartQuery

        edit.minimumWidth = minimumWidth
        edit.maximumWidth = maximumWidth

        edit.topOffset = topOffset
        edit.footerHeight = footerHeight

        edit.leadingPercentage = leadingPercentage
        edit.centerText = centerText
        edit.showTitle = showTitle
        edit.scrollToElementId = scrollToElementId

        if focusOnAppear {
            _ = edit.becomeFirstResponder()
        }

        let scrollView = NSScrollView()
        scrollView.automaticallyAdjustsContentInsets = false

        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .left, relatedBy: .equal, toItem: edit, attribute: .left, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .top, relatedBy: .equal, toItem: edit, attribute: .top, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .right, relatedBy: .equal, toItem: edit, attribute: .right, multiplier: 1.0, constant: 0))

        edit.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = edit

        context.coordinator.adjustScrollViewContentAutomatically(scrollView)
        return scrollView
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let edit = nsView.documentView as? BeamTextEdit else { return }

        if edit.note !== note {
            edit.note = note
            if focusOnAppear {
                _ = edit.becomeFirstResponder()
            }
        }

        edit.openURL = openURL
        edit.openCard = openCard
        edit.onStartEditing = onStartEditing
        edit.onEndEditing = onEndEditing
        edit.onStartQuery = onStartQuery

        edit.minimumWidth = minimumWidth
        edit.maximumWidth = maximumWidth

        edit.topOffset = topOffset
        edit.footerHeight = footerHeight

        edit.centerText = centerText
        edit.showTitle = showTitle

        edit.scrollToElementId = scrollToElementId

        context.coordinator.onDeinit = {
            edit.hideFloatingView()
        }
    }

    public class BTextEditScrollableCoordinator: NSObject {
        let parent: BTextEditScrollable
        var onDeinit: () -> Void = {}
        internal var scrollViewContentAdjuster: ScrollViewContentAdjuster?

        init(_ edit: BTextEditScrollable) {
            self.parent = edit
        }

        func adjustScrollViewContentAutomatically(_ scrollView: NSScrollView) {
            scrollViewContentAdjuster = ScrollViewContentAdjuster(with: scrollView)
            scrollViewContentAdjuster?.onScroll = parent.onScroll
        }

        deinit {
            onDeinit()
        }
    }

    public typealias NSViewType = NSScrollView
}

/**
 A NSScrollView helper that will adjust behavior when resizing the container or content.
 Currently only support content height becoming smaller.
*/
@objc class ScrollViewContentAdjuster: NSObject {
    var onScroll: ((CGPoint) -> Void)?
    private var lastContentBounds: NSRect = .zero

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
        onScroll?(clipView.bounds.origin)
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
            scrollView.scroll(scrollView.contentView, to: previousContentOffset)
        } else {
            lastContentBounds.origin = scrollView.contentView.bounds.origin
        }
        lastContentBounds.size = contentSize
    }
}
