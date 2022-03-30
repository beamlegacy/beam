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

public struct BTextEditScrollable<Content: View>: NSViewRepresentable {
    public typealias NSViewType = NSScrollView

    var note: BeamNote
    var state: BeamState
    var openURL: (URL, BeamElement) -> Void
    var openCard: (_ noteId: UUID, _ elementId: UUID?, _ unfold: Bool?) -> Void
    var startQuery: (TextNode, Bool) -> Void = { _, _ in }

    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var onFocusChanged: ((UUID, Int) -> Void)?
    var onScroll: ((CGPoint) -> Void)?
    var onSearchToggle: (SearchViewModel?) -> Void = { _ in }

    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024
    var topOffset = CGFloat(28)
    var scrollViewTopInset: CGFloat = 0
    var footerHeight = CGFloat(28)
    var leadingPercentage = PreferencesManager.editorLeadingPercentage
    var centerText = PreferencesManager.editorIsCentered
    var showTitle = true
    var initialFocusedState: NoteEditFocusedState?
    var initialScrollOffset: CGFloat?

    var headerView: () -> Content

    private let focusOnAppear = true

    public func makeCoordinator() -> BTextEditScrollableCoordinator {
        BTextEditScrollableCoordinator(self)
    }

    public func makeNSView(context: Context) -> NSViewType {
        let edit = BeamTextEdit(root: note, journalMode: false, enableDelayedInit: initialScrollOffset == nil)

        edit.state = state
        edit.initialScrollOffset = initialScrollOffset
        updateEditorProperties(edit, context: context)

        let scrollView = buildScrollView()
        edit.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = edit
        scrollView.contentView.addConstraints([
            scrollView.contentView.leftAnchor.constraint(equalTo: edit.leftAnchor),
            scrollView.contentView.rightAnchor.constraint(equalTo: edit.rightAnchor),
            scrollView.contentView.topAnchor.constraint(equalTo: edit.topAnchor)
        ])

        if let onScroll = onScroll {
            context.coordinator.observeScrollViewScroll(scrollView, onScroll: onScroll)
        }
        buildHeaderView(scrollView, context: context)
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
            context.coordinator.onDeinit = { [weak edit] in
                edit?.hideInlineFormatter()
            }
        }
        edit.frame = CGRect(origin: CGPoint.zero, size: edit.intrinsicContentSize)
    }

    private func updateEditorProperties(_ editor: BeamTextEdit, context: Context) {
        editor.openURL = openURL
        editor.openCard = openCard
        editor.startQuery = startQuery

        editor.onStartEditing = onStartEditing
        editor.onEndEditing = onEndEditing
        editor.onFocusChanged = onFocusChanged
        editor.onSearchToggle = onSearchToggle

        editor.minimumWidth = minimumWidth
        editor.maximumWidth = maximumWidth
        editor.topOffset = topOffset
        editor.footerHeight = footerHeight
        editor.leadingPercentage = leadingPercentage
        editor.centerText = centerText

        editor.showTitle = showTitle
    }

    private func focusEditor(_ editor: BeamTextEdit) {
        editor.scroll(.zero)
        DispatchQueue.main.async {
            if let fs = initialFocusedState {
                editor.focusElement(withId: fs.elementId, atCursorPosition: fs.cursorPosition, highlight: fs.highlight, unfold: fs.unfold)
            }
            editor.window?.makeFirstResponder(editor)
        }
    }

    private func buildHeaderView(_ scrollView: NSViewType, context: Context) {
        guard let documentView = scrollView.documentView else { return }
        context.coordinator.headerHostingView?.removeFromSuperview()
        let hosting = NSHostingController(rootView: headerView()).view
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.frame = documentView.bounds
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
        if scrollViewTopInset != 0 {
            scrollView.contentInsets = NSEdgeInsets(top: scrollViewTopInset, left: 0, bottom: 0, right: 0)
        }
        return scrollView
    }
}

extension BTextEditScrollable {
    public class BTextEditScrollableCoordinator: NSObject {
        private let parent: BTextEditScrollable
        fileprivate var onDeinit: () -> Void = {}
        fileprivate var onScroll: ((CGPoint) -> Void)?
        fileprivate var headerHostingView: NSView?

        init(_ edit: BTextEditScrollable) {
            self.parent = edit
        }

        deinit {
            onDeinit()
        }

        fileprivate func observeScrollViewScroll(_ scrollView: NSScrollView, onScroll: @escaping (CGPoint) -> Void) {
            self.onScroll = onScroll
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(contentOffsetDidChange(notification:)),
                                                   name: NSView.boundsDidChangeNotification,
                                                   object: scrollView.contentView)
        }

        @objc private func contentOffsetDidChange(notification: Notification) {
            guard let clipView = notification.object as? NSClipView else { return }
            parent.state.lastScrollOffset[parent.note.id] = clipView.bounds.origin.y.rounded() + 85
            onScroll?(clipView.bounds.origin)
        }
    }
}

extension NSScrollView: BeamTextEditContainer {
    func invalidateLayout() {
        guard let view = documentView else {
            invalidateIntrinsicContentSize()
            return
        }
        view.frame = CGRect(origin: .zero, size: view.intrinsicContentSize)
    }
}
